/*
INIT mercury_sys_init_call
ENDINIT
*/
/*
** Copyright (C) 1995-2004 The University of Melbourne.
** This file may only be copied under the terms of the GNU Library General
** Public License - see the file COPYING.LIB in the Mercury distribution.
*/

/*
** This module provides much of the functionality for doing higher order
** calls (with the rest provided by code generation of the generic_call
** HLDS construct), and most of the functionality for doing generic
** unifications and comparisons (with the rest provided by the
** compiler-generated unify, index and compare predicates).
*/

/*
** Note that the routines here don't need any special handling for
** accurate GC, since they only do tail-calls (or equivalent);
** their stack stack frames will never be live on the stack
** when a garbage collection occurs (or if they are, will never
** contain any live variables that might contain pointers to
** the Mercury heap).
*/

#include "mercury_imp.h"
#include "mercury_ho_call.h"
#include "mercury_type_desc.h"
#include "mercury_deep_profiling.h"
#include "mercury_deep_profiling_hand.h"
#include "mercury_layout_util.h"
#include "mercury_builtin_types.h"
#include "mercury_builtin_types_proc_layouts.h"
	/* for unify/compare of pred/func and for proc_layout structures */

#ifdef	MR_DEEP_PROFILING
  #ifdef MR_DEEP_PROFILING_STATISTICS
    #define	maybe_incr_prof_call_builtin_new()			\
			do { MR_deep_prof_call_builtin_new++; } while (0)
    #define	maybe_incr_prof_call_builtin_old()			\
			do { MR_deep_prof_call_builtin_old++; } while (0)
  #else
    #define	maybe_incr_prof_call_builtin_new()			\
			((void) 0)
    #define	maybe_incr_prof_call_builtin_old()			\
			((void) 0)
  #endif

  #ifdef MR_DEEP_PROFILING_EXPLICIT_CALL_COUNTS
    #define	maybe_incr_call_count(csd)				\
			do { csd->MR_csd_own.MR_own_calls++; } while (0)
  #else
    #define	maybe_incr_call_count(csd)				\
			((void) 0)
  #endif

  #define	special_pred_call_leave_code(pl, field)			\
	do {								\
		MR_CallSiteDynamic	*csd;				\
		MR_ProcDynamic		*pd;				\
									\
		csd = MR_next_call_site_dynamic;			\
		pd = csd->MR_csd_callee_ptr;				\
		if (pd == NULL) {					\
			MR_new_proc_dynamic(pd, (MR_Proc_Layout *) &pl); \
			csd->MR_csd_callee_ptr = pd;			\
			maybe_incr_prof_call_builtin_new();		\
		} else {						\
			maybe_incr_prof_call_builtin_old();		\
		}							\
		maybe_incr_call_count(csd);				\
		csd->MR_csd_own.field++;				\
	} while (0)

  #define	unify_call_exit_code(mod, pred, type, a)		\
	special_pred_call_leave_code(					\
		MR_proc_layout_uci_name(mod, pred, type, a, 0),		\
		MR_own_exits)

  #define	unify_call_fail_code(mod, pred, type, a)		\
	special_pred_call_leave_code(					\
		MR_proc_layout_uci_name(mod, pred, type, a, 0),		\
		MR_own_fails)

  #define	compare_call_exit_code(mod, pred, type, a)		\
	special_pred_call_leave_code(					\
		MR_proc_layout_uci_name(mod, pred, type, a, 0),		\
		MR_own_exits)

#endif

#ifdef MR_HIGHLEVEL_CODE

static MR_bool MR_CALL
unify_tuples(MR_Mercury_Type_Info ti, MR_Tuple x, MR_Tuple y)
{
	int		i, arity;
	MR_bool		result;
	MR_TypeInfo	type_info;
	MR_TypeInfo	arg_type_info;

	type_info = (MR_TypeInfo) ti;
	arity = MR_TYPEINFO_GET_VAR_ARITY_ARITY(type_info);

	for (i = 0; i < arity; i++) {
		/* type_infos are counted starting at one. */
		arg_type_info =
			MR_TYPEINFO_GET_VAR_ARITY_ARG_VECTOR(type_info)[i + 1];
		result = mercury__builtin__unify_2_p_0(
			(MR_Mercury_Type_Info) arg_type_info, x[i], y[i]);
		if (result == MR_FALSE) {
			return MR_FALSE;
		}
	}
	return MR_TRUE;
}

static void MR_CALL
compare_tuples(MR_Mercury_Type_Info ti, MR_Comparison_Result *result,
	MR_Tuple x, MR_Tuple y)
{
	int		i, arity;
	MR_TypeInfo	type_info;
	MR_TypeInfo	arg_type_info;

	type_info = (MR_TypeInfo) ti;
	arity = MR_TYPEINFO_GET_VAR_ARITY_ARITY(type_info);

	for (i = 0; i < arity; i++) {
		/* type_infos are counted starting at one. */
		arg_type_info =
			MR_TYPEINFO_GET_VAR_ARITY_ARG_VECTOR(type_info)[i + 1];
		mercury__builtin__compare_3_p_0(
			(MR_Mercury_Type_Info) arg_type_info,
			result, x[i], y[i]);
		if (*result != MR_COMPARE_EQUAL) {
			return;
		}
	}
	*result = MR_COMPARE_EQUAL;
}

/*
** Define the generic unify/2 and compare/3 functions.
*/

MR_bool MR_CALL
mercury__builtin__unify_2_p_0(MR_Mercury_Type_Info ti, MR_Box x, MR_Box y)
{
	MR_TypeInfo		type_info;
	MR_TypeCtorInfo		type_ctor_info;
	MR_TypeCtorRep		type_ctor_rep;
	int			arity;
	MR_TypeInfoParams	params;
	MR_Mercury_Type_Info	*args;

	type_info = (MR_TypeInfo) ti;
	type_ctor_info = MR_TYPEINFO_GET_TYPE_CTOR_INFO(type_info);

	/*
	** Tuple and higher-order types do not have a fixed arity,
	** so they need to be special cased here.
	*/
	type_ctor_rep = MR_type_ctor_rep(type_ctor_info);
	if (type_ctor_rep == MR_TYPECTOR_REP_TUPLE) {
		return unify_tuples(ti, (MR_Tuple) x, (MR_Tuple) y);
	} else if (type_ctor_rep == MR_TYPECTOR_REP_PRED) {
		return mercury__builtin____Unify____pred_0_0((MR_Pred) x,
			(MR_Pred) y);
	} else if (type_ctor_rep == MR_TYPECTOR_REP_FUNC) {
		return mercury__builtin____Unify____pred_0_0((MR_Pred) x,
			(MR_Pred) y);
	}

	arity = type_ctor_info->MR_type_ctor_arity;
	params = MR_TYPEINFO_GET_FIXED_ARITY_ARG_VECTOR(type_info);
	args = (MR_Mercury_Type_Info *) params;

	switch(arity) {
		/*
		** cast type_ctor_info->unify_pred to the right type
		** and then call it, passing the right number of
		** type_info arguments
		*/
		case 0: return ((MR_UnifyFunc_0 *)
				type_ctor_info->MR_type_ctor_unify_pred)
				(x, y);
		case 1: return ((MR_UnifyFunc_1 *)
				type_ctor_info->MR_type_ctor_unify_pred)
				(args[1], x, y);
		case 2: return ((MR_UnifyFunc_2 *)
				type_ctor_info->MR_type_ctor_unify_pred)
				(args[1], args[2], x, y);
		case 3: return ((MR_UnifyFunc_3 *)
				type_ctor_info->MR_type_ctor_unify_pred)
				(args[1], args[2], args[3],
				 x, y);
		case 4: return ((MR_UnifyFunc_4 *)
				type_ctor_info->MR_type_ctor_unify_pred)
				(args[1], args[2], args[3],
				 args[4], x, y);
		case 5: return ((MR_UnifyFunc_5 *)
				type_ctor_info->MR_type_ctor_unify_pred)
				(args[1], args[2], args[3],
				 args[4], args[5], x, y);
		default:
			MR_fatal_error(
				"unify/2: type arity > 5 not supported");
	}
}

void MR_CALL
mercury__builtin__compare_3_p_0(MR_Mercury_Type_Info ti,
	MR_Comparison_Result *res, MR_Box x, MR_Box y)
{
	MR_TypeInfo		type_info;
	MR_TypeCtorInfo		type_ctor_info;
	MR_TypeCtorRep		type_ctor_rep;
	int			arity;
	MR_TypeInfoParams	params;
	MR_Mercury_Type_Info	*args;

	type_info = (MR_TypeInfo) ti;
	type_ctor_info = MR_TYPEINFO_GET_TYPE_CTOR_INFO(type_info);

	/*
	** Tuple and higher-order types do not have a fixed arity,
	** so they need to be special cased here.
	*/
	type_ctor_rep = MR_type_ctor_rep(type_ctor_info);
	if (type_ctor_rep == MR_TYPECTOR_REP_TUPLE) {
		compare_tuples(ti, res, (MR_Tuple) x, (MR_Tuple) y);
		return;
	} else if (type_ctor_rep == MR_TYPECTOR_REP_PRED) {
		mercury__builtin____Compare____pred_0_0(res,
			(MR_Pred) x, (MR_Pred) y);
		return;
	} else if (type_ctor_rep == MR_TYPECTOR_REP_FUNC) {
		mercury__builtin____Compare____pred_0_0(res,
			(MR_Pred) x, (MR_Pred) y);
	    	return;
	}

	arity = type_ctor_info->MR_type_ctor_arity;
	params = MR_TYPEINFO_GET_FIXED_ARITY_ARG_VECTOR(type_info);
	args = (MR_Mercury_Type_Info *) params;

	switch(arity) {
		/*
		** cast type_ctor_info->compare to the right type
		** and then call it, passing the right number of
		** type_info arguments
		*/
		case 0: ((MR_CompareFunc_0 *)
			 type_ctor_info->MR_type_ctor_compare_pred)
			 (res, x, y);
			 break;
		case 1: ((MR_CompareFunc_1 *)
			 type_ctor_info->MR_type_ctor_compare_pred)
			 (args[1], res, x, y);
			 break;
		case 2: ((MR_CompareFunc_2 *)
			 type_ctor_info->MR_type_ctor_compare_pred)
			 (args[1], args[2], res, x, y);
			 break;
		case 3: ((MR_CompareFunc_3 *)
			 type_ctor_info->MR_type_ctor_compare_pred)
			 (args[1], args[2], args[3], res, x, y);
			 break;
		case 4: ((MR_CompareFunc_4 *)
			 type_ctor_info->MR_type_ctor_compare_pred)
			 (args[1], args[2], args[3],
			  args[4], res, x, y);
			 break;
		case 5: ((MR_CompareFunc_5 *)
			 type_ctor_info->MR_type_ctor_compare_pred)
			 (args[1], args[2], args[3],
			  args[4], args[5], res, x, y);
			 break;
		default:
			MR_fatal_error(
				"index/2: type arity > 5 not supported");
	}
}

void MR_CALL
mercury__builtin__compare_3_p_1(
	MR_Mercury_Type_Info type_info, MR_Comparison_Result *res,
	MR_Box x, MR_Box y)
{
	mercury__builtin__compare_3_p_0(type_info, res, x, y);
}

void MR_CALL
mercury__builtin__compare_3_p_2(
	MR_Mercury_Type_Info type_info, MR_Comparison_Result *res,
	MR_Box x, MR_Box y)
{
	mercury__builtin__compare_3_p_0(type_info, res, x, y);
}

void MR_CALL
mercury__builtin__compare_3_p_3(
	MR_Mercury_Type_Info type_info, MR_Comparison_Result *res,
	MR_Box x, MR_Box y)
{
	mercury__builtin__compare_3_p_0(type_info, res, x, y);
}

void MR_CALL
mercury__builtin__compare_representation_3_p_0(MR_Mercury_Type_Info ti,
	MR_Comparison_Result *res, MR_Box x, MR_Box y)
{
	MR_SORRY("compare_representation/3 for HIGHLEVEL_CODE");
}

#else	/* ! MR_HIGHLEVEL_CODE */

static	MR_Word	MR_generic_compare(MR_TypeInfo type_info, MR_Word x, MR_Word y);
static	MR_Word	MR_generic_unify(MR_TypeInfo type_info, MR_Word x, MR_Word y);
static	MR_Word	MR_generic_compare_representation(MR_TypeInfo type_info,
			MR_Word x, MR_Word y);
static	MR_Word	MR_compare_closures(MR_Closure *x, MR_Closure *y);

/*
** The called closure may contain only input arguments. The extra arguments
** provided by the higher-order call may be input or output, and may appear
** in any order.
**
** The input arguments to do_call_closure_compact are the closure in MR_r1,
** the number of additional input arguments in MR_r2, and the additional input
** arguments themselves in MR_r3, MR_r4, etc. The output arguments are
** returned in registers MR_r1, MR_r2, etc for det and nondet calls or
** registers MR_r2, MR_r3, etc for semidet calls.
**
** The placement of the extra input arguments into MR_r3, MR_r4 etc is done by
** the code generator, as is the movement of the output arguments to their
** eventual destinations.
*/

	/*
	** Number of input arguments to do_call_*_closure_compact,
	** MR_r1 -> closure
	** MR_r2 -> number of immediate input arguments.
	*/
#define MR_HO_CALL_INPUTS_COMPACT	2

	/*
	** Number of input arguments to do_call_*_class_method_compact,
	** MR_r1 -> typeclass info
	** MR_r2 -> index of method in typeclass info
	** MR_r3 -> number of immediate input arguments.
	*/
#define MR_CLASS_METHOD_CALL_INPUTS_COMPACT	3

/*
** These are the real implementations of higher order calls and method calls.
*/

MR_define_extern_entry(mercury__do_call_closure_compact);
MR_define_extern_entry(mercury__do_call_class_method_compact);

/*
** These are the real implementations of unify and compare.
*/

MR_define_extern_entry(mercury__builtin__unify_2_0);
MR_define_extern_entry(mercury__builtin__compare_3_0);
MR_define_extern_entry(mercury__builtin__compare_3_1);
MR_define_extern_entry(mercury__builtin__compare_3_2);
MR_define_extern_entry(mercury__builtin__compare_3_3);
MR_declare_label(mercury__builtin__compare_3_0_i1);
MR_define_extern_entry(mercury__builtin__compare_representation_3_0);

MR_BEGIN_MODULE(call_module)
	MR_init_entry_an(mercury__do_call_closure_compact);
	MR_init_entry_an(mercury__do_call_class_method_compact);

	MR_init_entry_an(mercury__builtin__unify_2_0);
	MR_init_entry_an(mercury__builtin__compare_3_0);
	MR_init_entry_an(mercury__builtin__compare_3_1);
	MR_init_entry_an(mercury__builtin__compare_3_2);
	MR_init_entry_an(mercury__builtin__compare_3_3);
	MR_init_entry_an(mercury__builtin__compare_representation_3_0);
MR_BEGIN_CODE

/*
** Note: this routine gets ignored for profiling.
** That means it should be called using noprof_call()
** rather than call().  See comment in output_call in
** compiler/llds_out for explanation.
*/
MR_define_entry(mercury__do_call_closure_compact);
{
	MR_Closure	*closure;
	int		num_extra_args;	/* # of args provided by our caller */
	int		num_hidden_args;/* # of args hidden in the closure  */
	int		i;

	/*
	** These assignments to local variables allow the values
	** of the relevant registers to be printed in gdb without
	** worrying about which machine registers, if any, hold them.
	*/

	closure = (MR_Closure *) MR_r1;
	num_extra_args = MR_r2;
	num_hidden_args = closure->MR_closure_num_hidden_args;

	MR_save_registers();

	if (num_hidden_args < MR_HO_CALL_INPUTS_COMPACT) {
		/* copy to the left, from the left */
		for (i = 1; i <= num_extra_args; i++) {
			MR_virtual_reg(i + num_hidden_args) =
				MR_virtual_reg(i + MR_HO_CALL_INPUTS_COMPACT);
		}
	} else if (num_hidden_args > MR_HO_CALL_INPUTS_COMPACT) {
		/* copy to the right, from the right */
		for (i = num_extra_args; i > 0; i--) {
			MR_virtual_reg(i + num_hidden_args) =
				MR_virtual_reg(i + MR_HO_CALL_INPUTS_COMPACT);
		}
	} /* else the new args are in the right place */

	for (i = 1; i <= num_hidden_args; i++) {
		MR_virtual_reg(i) = closure->MR_closure_hidden_args(i);
	}

	MR_restore_registers();

	/*
	** Note that we pass MR_prof_ho_caller_proc rather than
	** MR_LABEL(mercury__do_call_closure_compact), so that the call
	** gets recorded as having come from our caller.
	*/
	MR_tailcall(closure->MR_closure_code, MR_prof_ho_caller_proc);
}

/*
** Note: this routine gets ignored for profiling.
** That means it should be called using noprof_call()
** rather than call().  See comment in output_call in
** compiler/llds_out for explanation.
*/
MR_define_entry(mercury__do_call_class_method_compact);
{
	MR_Word		type_class_info;
	MR_Integer	method_index;
	MR_Integer	num_input_args;
	MR_Code 	*destination;
	MR_Integer	num_extra_instance_args;
	int		i;

	/*
	** These assignments to local variables allow the values
	** of the relevant registers to be printed in gdb without
	** worrying about which machine registers, if any, hold them.
	*/

	type_class_info = MR_r1;
	method_index = (MR_Integer) MR_r2;
	num_input_args = MR_r3;

	destination = MR_typeclass_info_class_method(type_class_info,
		method_index);
	num_extra_instance_args = (MR_Integer)
		MR_typeclass_info_num_extra_instance_args(type_class_info);

	MR_save_registers();

	if (num_extra_instance_args < MR_CLASS_METHOD_CALL_INPUTS_COMPACT) {
		/* copy to the left, from the left */
		for (i = 1; i <= num_input_args; i++) {
			MR_virtual_reg(i + num_extra_instance_args) =
				MR_virtual_reg(i +
					MR_CLASS_METHOD_CALL_INPUTS_COMPACT);
		}
	} else if (num_extra_instance_args >
			MR_CLASS_METHOD_CALL_INPUTS_COMPACT)
	{
		/* copy to the right, from the right */
		for (i = num_input_args; i > 0; i--) {
			MR_virtual_reg(i + num_extra_instance_args) =
				MR_virtual_reg(i +
					MR_CLASS_METHOD_CALL_INPUTS_COMPACT);
		}
	} /* else the new args are in the right place */

	for (i = num_extra_instance_args; i > 0; i--) {
		MR_virtual_reg(i) = 
			MR_typeclass_info_extra_instance_arg(MR_virtual_reg(1),
				i);
	}

	MR_restore_registers();

	/*
	** Note that we pass MR_prof_ho_caller_proc rather than
	** MR_LABEL(mercury__do_call_class_method_compact), so that
	** the call gets recorded as having come from our caller.
	*/
	MR_tailcall(destination, MR_prof_ho_caller_proc);
}

/*
** mercury__builtin__unify_2_0 is called as `unify(TypeInfo, X, Y)'
** in the mode `unify(in, in, in) is semidet'.
*/

MR_define_entry(mercury__builtin__unify_2_0);
{

#define	DECLARE_LOCALS							\
	MR_TypeCtorInfo	type_ctor_info;					\
	MR_TypeInfo	type_info;					\
	MR_Word		x, y;						\
	MR_Code		*saved_succip;

#define initialize()							\
	do {								\
		type_info = (MR_TypeInfo) MR_r1;			\
		x = MR_r2;						\
		y = MR_r3;						\
		saved_succip = MR_succip;				\
	} while(0)

#define raw_return_answer(answer)					\
	do {								\
		MR_r1 = (answer);					\
		MR_succip = saved_succip;				\
		MR_proceed();						\
	} while(0)

#define	tailcall_user_pred()						\
	MR_tailcall(type_ctor_info->MR_type_ctor_unify_pred, 		\
		MR_LABEL(mercury__builtin__unify_2_0))

#define	start_label		unify_start
#define	call_user_code_label	call_unify_in_proc
#define	type_stat_struct	MR_type_stat_mer_unify
#define	attempt_msg		"attempt to unify "
#define	entry_point_is_mercury

#include "mercury_unify_compare_body.h"

#undef	DECLARE_LOCALS
#undef	initialize
#undef	raw_return_answer
#undef	tailcall_user_pred
#undef	start_label
#undef	call_user_code_label
#undef	type_stat_struct
#undef	attempt_msg
#undef	entry_point_is_mercury

}

/*
** mercury__builtin__compare_3_3 is called as `compare(TypeInfo, Result, X, Y)'
** in the mode `compare(in, out, in, in) is det'.
**
** (The additional entry points replace either or both "in"s with "ui"s.)
*/

MR_define_entry(mercury__builtin__compare_3_0);
#ifdef MR_MPROF_PROFILE_CALLS
{
	MR_tailcall(MR_ENTRY(mercury__builtin__compare_3_3),
		MR_LABEL(mercury__builtin__compare_3_0));
}
#endif
MR_define_entry(mercury__builtin__compare_3_1);
#ifdef MR_MPROF_PROFILE_CALLS
{
	MR_tailcall(MR_ENTRY(mercury__builtin__compare_3_3),
		MR_LABEL(mercury__builtin__compare_3_1));
}
#endif
MR_define_entry(mercury__builtin__compare_3_2);
#ifdef MR_MPROF_PROFILE_CALLS
{
	MR_tailcall(MR_ENTRY(mercury__builtin__compare_3_3),
		MR_LABEL(mercury__builtin__compare_3_2));
}
#endif
MR_define_entry(mercury__builtin__compare_3_3);
{

#define	DECLARE_LOCALS							\
	MR_TypeCtorInfo	type_ctor_info;					\
	MR_TypeInfo	type_info;					\
	MR_Word		x, y;						\
	MR_Code		*saved_succip;

#define initialize()							\
	do {								\
		type_info = (MR_TypeInfo) MR_r1;			\
		x = MR_r2;						\
		y = MR_r3;						\
		saved_succip = MR_succip;				\
	} while(0)

#define raw_return_answer(answer)					\
	do {								\
		MR_r1 = (answer);					\
		MR_succip = saved_succip;				\
		MR_proceed();						\
	} while(0)

#define	tailcall_user_pred()						\
	MR_tailcall(type_ctor_info->MR_type_ctor_compare_pred,		\
		MR_LABEL(mercury__builtin__compare_3_3))

#define	start_label		compare_start
#define	call_user_code_label	call_compare_in_proc
#define	type_stat_struct	MR_type_stat_mer_compare
#define	attempt_msg		"attempt to compare "
#define	select_compare_code
#define	entry_point_is_mercury

#include "mercury_unify_compare_body.h"

#undef	DECLARE_LOCALS
#undef	initialize
#undef	raw_return_answer
#undef	tailcall_user_pred
#undef	start_label
#undef	call_user_code_label
#undef	type_stat_struct
#undef	attempt_msg
#undef	select_compare_code
#undef	entry_point_is_mercury

}

/*
** mercury__builtin__compare_representation_3_0 is called as
** `compare_representation(TypeInfo, Result, X, Y)' in the mode
** `compare_representation(in, uo, in, in) is cc_multi'.
*/

MR_define_entry(mercury__builtin__compare_representation_3_0);
{

#define	DECLARE_LOCALS							\
	MR_TypeCtorInfo	type_ctor_info;					\
	MR_TypeInfo	type_info;					\
	MR_Word		x, y;						\
	MR_Code		*saved_succip;

#define initialize()							\
	do {								\
		type_info = (MR_TypeInfo) MR_r1;			\
		x = MR_r2;						\
		y = MR_r3;						\
		saved_succip = MR_succip;				\
	} while(0)

#define raw_return_answer(answer)					\
	do {								\
		MR_r1 = (answer);					\
		MR_succip = saved_succip;				\
		MR_proceed();						\
	} while(0)

#define	start_label		compare_rep_start
#define	call_user_code_label	call_compare_rep_in_proc
#define	type_stat_struct	MR_type_stat_mer_compare
#define	attempt_msg		"attempt to compare representation "
#define	select_compare_code
#define	include_compare_rep_code
#define	entry_point_is_mercury

#include "mercury_unify_compare_body.h"

#undef	DECLARE_LOCALS
#undef	initialize
#undef	raw_return_answer
#undef	start_label
#undef	call_user_code_label
#undef	type_stat_struct
#undef	attempt_msg
#undef	select_compare_code
#undef	include_compare_rep_code
#undef	entry_point_is_mercury

}

MR_END_MODULE

static MR_Word
MR_generic_unify(MR_TypeInfo type_info, MR_Word x, MR_Word y)
{

#define	DECLARE_LOCALS							\
	MR_TypeCtorInfo	type_ctor_info;

#define initialize()							\
	do {								\
		MR_restore_transient_registers();			\
	} while (0)

#define raw_return_answer(answer)					\
	do {								\
		MR_save_transient_registers();				\
		return (answer);					\
	} while (0)

#define	tailcall_user_pred()						\
	do {								\
		MR_save_transient_registers();				\
		(void) MR_call_engine(type_ctor_info->			\
			MR_type_ctor_unify_pred, MR_FALSE);		\
		MR_restore_transient_registers();			\
		return (MR_r1);						\
	} while (0)

#define	start_label		unify_func_start
#define	call_user_code_label	call_unify_in_func
#define	type_stat_struct	MR_type_stat_c_unify
#define	attempt_msg		"attempt to unify "

#include "mercury_unify_compare_body.h"

#undef	DECLARE_LOCALS
#undef	initialize
#undef	raw_return_answer
#undef	tailcall_user_pred
#undef	start_label
#undef	call_user_code_label
#undef	type_stat_struct
#undef	attempt_msg
}

static MR_Word
MR_generic_compare(MR_TypeInfo type_info, MR_Word x, MR_Word y)
{
#define	DECLARE_LOCALS							\
	MR_TypeCtorInfo	type_ctor_info;

#define initialize()							\
	do {								\
		MR_restore_transient_registers();			\
	} while (0)

#define raw_return_answer(answer)					\
	do {								\
		MR_save_transient_registers();				\
		return (answer);					\
	} while (0)

#define	tailcall_user_pred()						\
	do {								\
		MR_save_transient_registers();				\
		(void) MR_call_engine(type_ctor_info->			\
			MR_type_ctor_compare_pred, MR_FALSE);		\
		MR_restore_transient_registers();			\
		return (MR_r1);						\
	} while (0)

#define	start_label		compare_func_start
#define	call_user_code_label	call_compare_in_func
#define	type_stat_struct	MR_type_stat_c_compare
#define	attempt_msg		"attempt to compare "
#define	select_compare_code

#include "mercury_unify_compare_body.h"

#undef	DECLARE_LOCALS
#undef	initialize
#undef	raw_return_answer
#undef	tailcall_user_pred
#undef	start_label
#undef	call_user_code_label
#undef	type_stat_struct
#undef	attempt_msg
#undef	select_compare_code
}

static MR_Word
MR_generic_compare_representation(MR_TypeInfo type_info, MR_Word x, MR_Word y)
{
#define	DECLARE_LOCALS							\
	MR_TypeCtorInfo	type_ctor_info;

#define initialize()							\
	do {								\
		MR_restore_transient_registers();			\
	} while (0)

#define raw_return_answer(answer)					\
	do {								\
		MR_save_transient_registers();				\
		return (answer);					\
	} while (0)

#define	start_label		compare_rep_func_start
#define	call_user_code_label	call_compare_rep_in_func
#define	type_stat_struct	MR_type_stat_c_compare
#define	attempt_msg		"attempt to compare representation"
#define	select_compare_code
#define	include_compare_rep_code

#include "mercury_unify_compare_body.h"

#undef	DECLARE_LOCALS
#undef	initialize
#undef	raw_return_answer
#undef	start_label
#undef	call_user_code_label
#undef	type_stat_struct
#undef	attempt_msg
#undef	select_compare_code
#undef	include_compare_rep_code
}

static	MR_Word
MR_compare_closures(MR_Closure *x, MR_Closure *y)
{
	MR_Closure_Layout   *x_layout;
	MR_Closure_Layout   *y_layout;
	MR_Proc_Id          *x_proc_id;
	MR_Proc_Id          *y_proc_id;
	MR_ConstString      x_module_name;
	MR_ConstString      y_module_name;
	MR_ConstString      x_pred_name;
	MR_ConstString      y_pred_name;
	MR_TypeInfo         *x_type_params;
	MR_TypeInfo         *y_type_params;
	int                 x_num_args;
	int                 y_num_args;
	int                 num_args;
	int                 i;
	int                 result;

	/*
	** Optimize the simple case.
	*/
	if (x == y) {
		return MR_COMPARE_EQUAL;
	}

	x_layout = x->MR_closure_layout;
	y_layout = y->MR_closure_layout;

	x_proc_id = &x_layout->MR_closure_id->MR_closure_proc_id;
	y_proc_id = &y_layout->MR_closure_id->MR_closure_proc_id;

	if (x_proc_id != y_proc_id) {
		if (MR_PROC_ID_IS_UCI(*x_proc_id)) {
			x_module_name = x_proc_id->MR_proc_uci.
						MR_uci_def_module;
			x_pred_name = x_proc_id->MR_proc_uci.MR_uci_pred_name;
		} else {
			x_module_name = x_proc_id->MR_proc_user.
						MR_user_decl_module;
			x_pred_name = x_proc_id->MR_proc_user.MR_user_name;
		}
		if (MR_PROC_ID_IS_UCI(*y_proc_id)) {
			y_module_name = y_proc_id->MR_proc_uci.
						MR_uci_def_module;
			y_pred_name = y_proc_id->MR_proc_uci.MR_uci_pred_name;
		} else {
			y_module_name = y_proc_id->MR_proc_user.
						MR_user_decl_module;
			y_pred_name = y_proc_id->MR_proc_user.MR_user_name;
		}

		result = strcmp(x_module_name, y_module_name);
		if (result < 0) {
			return MR_COMPARE_LESS;
		} else if (result > 0) {
			return MR_COMPARE_GREATER;
		}

		result = strcmp(x_pred_name, y_pred_name);
		if (result < 0) {
			return MR_COMPARE_LESS;
		} else if (result > 0) {
			return MR_COMPARE_GREATER;
		}
	}

	x_num_args = x->MR_closure_num_hidden_args;
	y_num_args = y->MR_closure_num_hidden_args;
	if (x_num_args < y_num_args) {
		return MR_COMPARE_LESS;
	} else if (x_num_args > y_num_args) {
		return MR_COMPARE_GREATER;
	}

	num_args = x_num_args;
	x_type_params = MR_materialize_closure_type_params(x);
	y_type_params = MR_materialize_closure_type_params(y);
	for (i = 0; i < num_args; i++) {
		MR_TypeInfo	x_arg_type_info;
		MR_TypeInfo	y_arg_type_info;
		MR_TypeInfo	arg_type_info;

		x_arg_type_info = MR_create_type_info(x_type_params,
				x_layout->MR_closure_arg_pseudo_type_info[i]);
		y_arg_type_info = MR_create_type_info(y_type_params,
				y_layout->MR_closure_arg_pseudo_type_info[i]);
		result = MR_compare_type_info(x_arg_type_info, y_arg_type_info);
		if (result != MR_COMPARE_EQUAL) {
			goto finish_closure_compare;
		}

		arg_type_info = x_arg_type_info;
		result = MR_generic_compare(arg_type_info,
				x->MR_closure_hidden_args_0[i],
				y->MR_closure_hidden_args_0[i]);
		if (result != MR_COMPARE_EQUAL) {
			goto finish_closure_compare;
		}
	}

	result = MR_COMPARE_EQUAL;

finish_closure_compare:
	if (x_type_params != NULL) {
		MR_free(x_type_params);
	}
	if (y_type_params != NULL) {
		MR_free(y_type_params);
	}
	return result;
}

#endif /* not MR_HIGHLEVEL_CODE */

/*---------------------------------------------------------------------------*/
/*
** Code to construct closures, for use by browser/dl.m and Aditi.
*/

#ifdef MR_HIGHLEVEL_CODE
extern MR_Box MR_CALL MR_generic_closure_wrapper(void *closure,
	MR_Box arg1, MR_Box arg2, MR_Box arg3, MR_Box arg4, MR_Box arg5,
	MR_Box arg6, MR_Box arg7, MR_Box arg8, MR_Box arg9, MR_Box arg10,
	MR_Box arg11, MR_Box arg12, MR_Box arg13, MR_Box arg14, MR_Box arg15,
	MR_Box arg16, MR_Box arg17, MR_Box arg18, MR_Box arg19, MR_Box arg20);
#endif

struct MR_Closure_Struct *
MR_make_closure(MR_Code *proc_addr)
{
	static	int			closure_counter = 0;
	MR_Closure			*closure;
	MR_Closure_Id			*closure_id;
	MR_Closure_Dyn_Link_Layout	*closure_layout;
	char				buf[80];
	int				num_hidden_args;

	MR_restore_transient_hp();

	/* create a goal path that encodes a unique id for this closure */
	closure_counter++;
	sprintf(buf, "@%d;", closure_counter);

	/*
	** XXX All the allocations in this code should use malloc
	** in deep profiling grades.
	*/

	/*
	** Construct the MR_Closure_Id.
	*/
	MR_incr_hp_type(closure_id, MR_Closure_Id);
	closure_id->MR_closure_proc_id.MR_proc_user.MR_user_pred_or_func =
		MR_PREDICATE;
	closure_id->MR_closure_proc_id.MR_proc_user.MR_user_decl_module =
		"unknown";
	closure_id->MR_closure_proc_id.MR_proc_user.MR_user_def_module =
		"unknown";
	closure_id->MR_closure_proc_id.MR_proc_user.MR_user_name = "unknown";
	closure_id->MR_closure_proc_id.MR_proc_user.MR_user_arity = -1;
	closure_id->MR_closure_proc_id.MR_proc_user.MR_user_mode = -1;
	closure_id->MR_closure_module_name = "dl";
	closure_id->MR_closure_file_name = __FILE__;
	closure_id->MR_closure_line_number = __LINE__;
	MR_make_aligned_string_copy(closure_id->MR_closure_goal_path, buf);

	/*
	** Construct the MR_Closure_Layout.
	*/
	MR_incr_hp_type(closure_layout, MR_Closure_Dyn_Link_Layout);
	closure_layout->MR_closure_dl_id = closure_id;
	closure_layout->MR_closure_dl_type_params = NULL;
	closure_layout->MR_closure_dl_num_all_args = 0;

	/*
	** Construct the MR_Closure.
	*/
#ifdef MR_HIGHLEVEL_CODE
	num_hidden_args = 1;
#else
	num_hidden_args = 0;
#endif
	MR_offset_incr_hp(MR_LVALUE_CAST(MR_Word, closure), 0,
		3 + num_hidden_args);

	closure->MR_closure_layout = (MR_Closure_Layout *) closure_layout;
	closure->MR_closure_code = proc_addr;
	closure->MR_closure_num_hidden_args = num_hidden_args;
#ifdef MR_HIGHLEVEL_CODE
	closure->MR_closure_hidden_args(1) =
		(MR_Word) &MR_generic_closure_wrapper;
#endif

	MR_save_transient_hp();
	return closure;
}

#ifdef MR_HIGHLEVEL_CODE
/*
** For the --high-level-code grades, the closure will be passed
** as an argument to the wrapper procedure.  The wrapper procedure
** then extracts any needed curried arguments from the closure,
** and calls the real procedure.  Normally the wrapper procedure
** knows which real procedure it will call, but for dl.m we use
** a generic wrapper procedure, and treat the real procedure
** as a curried argument of the generic wrapper.  That is always
** the only curried argument, so all the wrapper needs to do
** is to extract the procedure address from the closure, and
** then call it, passing the same arguments that it was passed,
** except for the closure itself.
**
** XXX Using a single generic wrapper procedure is a nasty hack. 
** We play fast and loose with the C type system here.  In reality
** this will get called with different return type, different
** argument types, and with fewer than 20 arguments.  Likewise, the
** procedure that it calls may actually have different arity, return type
** and argument types than we pass.  So we really ought to have lots of
** different wrapper procedures, for each different return type, number
** of arguments, and even for each different set of argument types.
** Doing it right might require run-time code generation!
** But with traditional C calling conventions, using a single wrapper
** like this will work anyway, at least for arguments whose type is the
** same size as MR_Box.  It fails for arguments of type `char' or `float'.
**
** XXX This will also fail for calling conventions where the callee pops the
** arguments.  To handle that right, we'd need different wrappers for
** each different number of arguments.  (Doing that would also be slightly
** more efficient, so it may worth doing...)
**
** There are also a couple of libraries called `ffcall' and `libffi'
** which we might be able use to do this in a more portable manner.
*/
MR_Box MR_CALL
MR_generic_closure_wrapper(void *closure,
	MR_Box arg1, MR_Box arg2, MR_Box arg3, MR_Box arg4, MR_Box arg5,
	MR_Box arg6, MR_Box arg7, MR_Box arg8, MR_Box arg9, MR_Box arg10,
	MR_Box arg11, MR_Box arg12, MR_Box arg13, MR_Box arg14, MR_Box arg15,
	MR_Box arg16, MR_Box arg17, MR_Box arg18, MR_Box arg19, MR_Box arg20)
{
	typedef MR_Box MR_CALL FuncType(
		MR_Box a1, MR_Box a2, MR_Box a3, MR_Box a4, MR_Box a5,
		MR_Box a6, MR_Box a7, MR_Box a8, MR_Box a9, MR_Box a10,
		MR_Box a11, MR_Box a12, MR_Box a13, MR_Box a14, MR_Box a15,
		MR_Box a16, MR_Box a17, MR_Box a18, MR_Box a19, MR_Box a20);
	FuncType *proc = (FuncType *)
		MR_field(MR_mktag(0), closure, (MR_Integer) 3);
	return (*proc)(arg1, arg2, arg3, arg4, arg5,
		arg6, arg7, arg8, arg9, arg10,
		arg11, arg12, arg13, arg14, arg15,
		arg16, arg17, arg18, arg19, arg20);
}
#endif /* MR_HIGHLEVEL_CODE */

/*
** The initialization function needs to be defined even when
** MR_HIGHLEVEL_CODE is set, because it will get included
** in the list of initialization functions that get called.
** So for MR_HIGHLEVEL_CODE it just does nothing.
*/

/* forward decls to suppress gcc warnings */
void mercury_sys_init_call_init(void);
void mercury_sys_init_call_init_type_tables(void);
#ifdef	MR_DEEP_PROFILING
void mercury_sys_init_call_write_out_proc_statics(FILE *fp);
#endif

void mercury_sys_init_call_init(void)
{
#ifndef MR_HIGHLEVEL_CODE
	call_module();
#endif /* not MR_HIGHLEVEL_CODE */
}

void mercury_sys_init_call_init_type_tables(void)
{
	/* no types to register */
}

#ifdef	MR_DEEP_PROFILING
void mercury_sys_init_call_write_out_proc_statics(FILE *fp)
{
}
#endif
