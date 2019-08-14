#include <mruby.h>
#include <mruby/string.h>

#define MRB_STR_FROZEN MRB_FL_OBJ_IS_FROZEN
#define DEFINE_FLAG_PREDICATE_FUNC(func, flag)                              \
  static mrb_value                                                          \
  str_##func##_p(mrb_state *mrb, mrb_value self)                            \
  {                                                                         \
    return mrb_bool_value(!!(mrb_str_ptr(self)->flags & MRB_STR_##flag));   \
  }

#define str_bytesize(mrb, self) mrb_fixnum_value(RSTRING_LEN(self))
#define INSPECT_INTERNAL(str, self, name, func) do {                        \
  mrb_str_cat_lit(mrb, str, "  " name " = ");                               \
  mrb_str_cat_str(mrb, str, mrb_inspect(mrb, str_##func(mrb, self)));       \
  mrb_str_cat_lit(mrb, str, "\n");                                          \
} while (0);

static mrb_value
str_s_embeddable_capacity(mrb_state *mrb, mrb_value klass)
{
  return mrb_fixnum_value(RSTRING_EMBED_LEN_MAX);
}

DEFINE_FLAG_PREDICATE_FUNC(frozen, FROZEN)
DEFINE_FLAG_PREDICATE_FUNC(embedded, EMBED)
DEFINE_FLAG_PREDICATE_FUNC(shared, SHARED)
DEFINE_FLAG_PREDICATE_FUNC(fshared, FSHARED)
DEFINE_FLAG_PREDICATE_FUNC(pool, POOL)
DEFINE_FLAG_PREDICATE_FUNC(nofree, NOFREE)
DEFINE_FLAG_PREDICATE_FUNC(ascii, ASCII)

static mrb_value
str_null_terminated_p(mrb_state *mrb, mrb_value self)
{
  return mrb_bool_value(!RSTRING_PTR(self)[RSTRING_LEN(self)]);
}

static mrb_value
str_capacity(mrb_state *mrb, mrb_value self)
{
  return mrb_fixnum_value(RSTRING_CAPA(self));
}

static mrb_value
str_internal_inspect(mrb_state *mrb, mrb_value self)
{
  mrb_value str = mrb_any_to_s(mrb, self);
  *(RSTRING_END(str)-1) = ' ';
  mrb_str_cat_str(mrb, str, mrb_str_dump(mrb, self));
  mrb_str_cat_lit(mrb, str, "\n");
  INSPECT_INTERNAL(str, self, "         frozen?", frozen_p);
  INSPECT_INTERNAL(str, self, "       embedded?", embedded_p);
  INSPECT_INTERNAL(str, self, "         shared?", shared_p);
  INSPECT_INTERNAL(str, self, "        fshared?", fshared_p);
  INSPECT_INTERNAL(str, self, "           pool?", pool_p);
  INSPECT_INTERNAL(str, self, "         nofree?", nofree_p);
  INSPECT_INTERNAL(str, self, "          ascii?", ascii_p);
  INSPECT_INTERNAL(str, self, "null_terminated?", null_terminated_p);
  INSPECT_INTERNAL(str, self, "        bytesize", bytesize);
  INSPECT_INTERNAL(str, self, "        capacity", capacity);
  mrb_str_cat_lit(mrb, str, ">");
  return str;
}

void
mrb_mruby_object_internal_init_string(mrb_state* mrb)
{
  struct RClass * s = mrb->string_class;
  mrb_define_class_method(mrb, s, "embeddable_capacity", str_s_embeddable_capacity, MRB_ARGS_NONE());
  mrb_define_method(mrb, s, "embedded?", str_embedded_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, s, "shared?", str_shared_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, s, "fshared?", str_fshared_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, s, "pool?", str_pool_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, s, "nofree?", str_nofree_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, s, "ascii?", str_ascii_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, s, "null_terminated?", str_null_terminated_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, s, "capacity", str_capacity, MRB_ARGS_NONE());
  mrb_define_method(mrb, s, "internal_inspect", str_internal_inspect, MRB_ARGS_NONE());
  mrb_define_method(mrb, s, "ii", str_internal_inspect, MRB_ARGS_NONE());
//  mrb_define_method(mrb, s, "reference_count", str_reference_count, MRB_ARGS_NONE());
}
