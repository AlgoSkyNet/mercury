%---------------------------------------------------------------------------%
% Copyright (C) 2003 The University of Melbourne.
% This file may only be copied under the terms of the GNU General
% Public License - see the file COPYING in the Mercury distribution.
%---------------------------------------------------------------------------%
%
% This module generates the RTTI data for the global variables (or constants)
% that hold the data structures representing the type class and instance
% declarations in the current module.
%
% For now, this module is not invoked by default, and the data structures it
% generates are used only by the debugger to inform the user, not by the
% runtime system to invoke type class methods.
%
% Author: zs.
%
%---------------------------------------------------------------------------%

:- module backend_libs__type_class_info.

:- interface.

:- import_module backend_libs__rtti.
:- import_module hlds__hlds_module.

:- import_module list.

:- pred type_class_info__generate_rtti(module_info::in, list(rtti_data)::out)
	is det.

:- implementation.

:- import_module check_hlds__type_util.
:- import_module hlds__hlds_data.
:- import_module hlds__hlds_out.
:- import_module hlds__hlds_pred.
:- import_module libs__globals.
:- import_module libs__options.
:- import_module parse_tree__prog_data.
:- import_module parse_tree__prog_io.
:- import_module parse_tree__prog_out.
:- import_module backend_libs__pseudo_type_info.
:- import_module backend_libs__base_typeclass_info.

:- import_module bool, int, string, assoc_list, map.
:- import_module std_util, require, term, varset.

%---------------------------------------------------------------------------%

generate_rtti(ModuleInfo, RttiDatas) :-
	module_info_classes(ModuleInfo, ClassTable),
	map__to_assoc_list(ClassTable, Classes),
	list__foldl(generate_class_decl(ModuleInfo), Classes,
		[], RttiDatas0),
	module_info_instances(ModuleInfo, InstanceTable),
	map__to_assoc_list(InstanceTable, Instances),
	list__foldl(generate_instance_decls(ModuleInfo), Instances,
		RttiDatas0, RttiDatas).

%---------------------------------------------------------------------------%

:- pred generate_class_decl(module_info::in,
	pair(class_id, hlds_class_defn)::in,
	list(rtti_data)::in, list(rtti_data)::out) is det.

generate_class_decl(ModuleInfo, ClassId - ClassDefn, !RttiDatas) :-
	ImportStatus = ClassDefn ^ class_status,
	( status_defined_in_this_module(ImportStatus, yes) ->
		TCId = generate_class_id(ModuleInfo, ClassId, ClassDefn),
		Supers = ClassDefn ^ class_supers,
		TCSupers = list__map(generate_class_constraint, Supers),
		TCVersion = type_class_info_rtti_version,
		RttiData = type_class_decl(tc_decl(TCId, TCVersion, TCSupers)),
		!:RttiDatas = [RttiData | !.RttiDatas]
	;
		true
	).

:- func generate_class_id(module_info, class_id, hlds_class_defn) = tc_id.

generate_class_id(ModuleInfo, ClassId, ClassDefn) = TCId :-
	TCName = generate_class_name(ClassId),
	ClassVars = ClassDefn ^ class_vars,
	ClassVarSet = ClassDefn ^ class_tvarset,
	list__map(varset__lookup_name(ClassVarSet), ClassVars, VarNames),
	Interface = ClassDefn ^ class_hlds_interface,
	MethodIds = list__map(generate_method_id(ModuleInfo), Interface),
	TCId = tc_id(TCName, VarNames, MethodIds).

:- func generate_method_id(module_info, hlds_class_proc) = tc_method_id.

generate_method_id(ModuleInfo, ClassProc) = MethodId :-
	ClassProc = hlds_class_proc(PredId, _ProcId),
	module_info_pred_info(ModuleInfo, PredId, PredInfo),
	pred_info_name(PredInfo, MethodName),
	pred_info_arity(PredInfo, Arity),
	pred_info_get_is_pred_or_func(PredInfo, PredOrFunc),
	MethodId = tc_method_id(MethodName, Arity, PredOrFunc).

%---------------------------------------------------------------------------%

:- pred generate_instance_decls(module_info::in,
	pair(class_id, list(hlds_instance_defn))::in,
	list(rtti_data)::in, list(rtti_data)::out) is det.

generate_instance_decls(ModuleInfo, ClassId - Instances, !RttiDatas) :-
	list__foldl(generate_maybe_instance_decl(ModuleInfo, ClassId),
		Instances, !RttiDatas).

:- pred generate_maybe_instance_decl(module_info::in,
	class_id::in, hlds_instance_defn::in,
	list(rtti_data)::in, list(rtti_data)::out) is det.

generate_maybe_instance_decl(ModuleInfo, ClassId, InstanceDefn, !RttiDatas) :-
	ImportStatus = InstanceDefn ^ instance_status,
	Body = InstanceDefn ^ instance_body,
	(
		Body = concrete(_),
			% Only make the RTTI structure for the type class
			% instance if the instance declaration originally
			% came from _this_ module.
		status_defined_in_this_module(ImportStatus, yes)
	->
		RttiData = generate_instance_decl(ModuleInfo, ClassId,
			InstanceDefn),
		!:RttiDatas = [RttiData | !.RttiDatas]
	;
		true
	).

:- func generate_instance_decl(module_info, class_id, hlds_instance_defn)
	= rtti_data.

generate_instance_decl(ModuleInfo, ClassId, Instance) = RttiData :-
	TCName = generate_class_name(ClassId),
	InstanceTypes = Instance ^ instance_types,
	InstanceTCTypes = list__map(generate_tc_type, InstanceTypes),
	TVarSet = Instance ^ instance_tvarset,
	varset__vars(TVarSet, TVars),
	TVarNums = list__map(term__var_to_int, TVars),
	TVarLength = list__length(TVarNums),
	( list__last(TVarNums, LastTVarNum) ->
		require(unify(TVarLength, LastTVarNum),
			"generate_instance_decl: tvar num mismatch"),
		NumTypeVars = TVarLength
	;
		NumTypeVars = 0
	),
	Constraints = Instance ^ instance_constraints,
	TCConstraints = list__map(generate_class_constraint, Constraints),
	MaybeInterface = Instance ^ instance_hlds_interface,
	(
		MaybeInterface = yes(Interface),
		MethodProcLabels = list__map(
			generate_method_proc_label(ModuleInfo), Interface)
	;
		MaybeInterface = no,
		error("generate_instance_decl: no interface")
	),
	TCInstance = tc_instance(TCName, InstanceTCTypes, NumTypeVars,
		TCConstraints, MethodProcLabels),
	RttiData = type_class_instance(TCInstance).

:- func generate_method_proc_label(module_info, hlds_class_proc) =
	rtti_proc_label.

generate_method_proc_label(ModuleInfo, hlds_class_proc(PredId, ProcId)) =
	make_rtti_proc_label(ModuleInfo, PredId, ProcId).

%---------------------------------------------------------------------------%

:- func generate_class_name(class_id) = tc_name.

generate_class_name(class_id(SymName, Arity)) = TCName :-
	(
		SymName = qualified(ModuleName, ClassName)
	;
		SymName = unqualified(_),
		error("generate_class_name: unqualified sym_name")
	),
	TCName = tc_name(ModuleName, ClassName, Arity).

:- func generate_class_constraint(class_constraint) = tc_constraint.

generate_class_constraint(constraint(ClassName, Types)) = TCConstr :-
	Arity = list__length(Types),
	ClassId = class_id(ClassName, Arity),
	TCClassName = generate_class_name(ClassId),
	ClassTypes = list__map(generate_tc_type, Types),
	TCConstr = tc_constraint(TCClassName, ClassTypes).

:- func generate_tc_type(type) = tc_type.

generate_tc_type(Type) = TCType :-
	pseudo_type_info__construct_maybe_pseudo_type_info(Type, -1, [],
		TCType).

%---------------------------------------------------------------------------%

% The version number of the runtime data structures describing type class
% information, most of which (currently, all of which) is generated in this
% module.
%
% The value returned by this function should be kept in sync with
% MR_TYPECLASS_VERSION in runtime/mercury_typeclass_info.h.

:- func type_class_info_rtti_version = int.

type_class_info_rtti_version = 0.

%---------------------------------------------------------------------------%
