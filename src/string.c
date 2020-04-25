#include <mruby.h>
#include <mruby/string.h>
#include <mruby/object_internal.h>

typedef struct mrb_shared_string {
  int refcnt;
  mrb_int capa;
  char *ptr;
} mrb_shared_string;

#define MRB_STR_FROZEN MRB_FL_OBJ_IS_FROZEN
#define DEFINE_FLAG_PREDICATE_FUNC(func, flag)                              \
  static mrb_value                                                          \
  str_##func##_p(mrb_state *mrb, mrb_value self)                            \
  {                                                                         \
    return mrb_bool_value(!!(RSTRING(self)->flags & MRB_STR_##flag));       \
  }

#define str_bytesize(mrb, self) \
  mrb_fixnum_value(RSTRING_LEN(self))
#define str_fshared_to_s(mrb, self) \
  simple_inspect(mrb, str_fshared(mrb, self), ">")

#define INSPECT_INTERNAL(str, self, name, func) do {                        \
  mrb_value ret__ = str_##func(mrb, self);                                  \
  if (!mrb_string_p(ret__)) ret__ = mrb_inspect(mrb, ret__);                \
  mrb_str_cat_lit(mrb, str, "  " name " = ");                               \
  mrb_str_cat_str(mrb, str, ret__);                                         \
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
DEFINE_FLAG_PREDICATE_FUNC(nofree, NOFREE)
DEFINE_FLAG_PREDICATE_FUNC(pool, POOL)
DEFINE_FLAG_PREDICATE_FUNC(ascii, ASCII)

static mrb_value
simple_inspect(mrb_state *mrb, mrb_value self, const char *suffix)
{
  mrb_value ret = mrb_any_to_s(mrb, self);
  *(RSTRING_END(ret)-1) = ' ';
  mrb_str_cat_str(mrb, ret, mrb_str_dump(mrb, self));
  mrb_str_cat_cstr(mrb, ret, suffix);
  return ret;
}

static mrb_value
str_ro_data_p(mrb_state *mrb, mrb_value self)
{
  return mrb_bool_value(mrb_ro_data_p(RSTRING_PTR(self)));
}

static mrb_value
str_null_terminated_p(mrb_state *mrb, mrb_value self)
{
  return mrb_bool_value(!RSTRING_PTR(self)[RSTRING_LEN(self)]);
}

static mrb_value
str_capacity(mrb_state *mrb, mrb_value self)
{
  struct RString *s = RSTRING(self);
  return RSTR_FSHARED_P(s) || RSTR_SHARED_P(s) ?
    mrb_nil_value() : mrb_fixnum_value(RSTRING_CAPA(self));
}

static mrb_value
str_fshared(mrb_state *mrb, mrb_value self)
{
  struct RString *s = RSTRING(self);
  return RSTR_FSHARED_P(s) ?
    mrb_obj_value(s->as.heap.aux.fshared) : mrb_nil_value();
}

static mrb_value
str_shared(mrb_state *mrb, mrb_value self)
{
  return mrb_obj_internal_ptr_to_str(mrb, RSTRING(self)->as.heap.aux.shared);
}

static mrb_value
str_shared_capacity(mrb_state *mrb, mrb_value self)
{
  struct RString *s = RSTRING(self);
  return RSTR_SHARED_P(s) ?
    mrb_fixnum_value(s->as.heap.aux.shared->capa) : mrb_nil_value();
}

static mrb_value
str_shared_reference_count(mrb_state *mrb, mrb_value self)
{
  struct RString *s = RSTRING(self);
  return RSTR_SHARED_P(s) ?
    mrb_fixnum_value(s->as.heap.aux.shared->refcnt) : mrb_nil_value();
}

static mrb_value
str_shared_pointer(mrb_state *mrb, mrb_value self)
{
  char *p = RSTRING(self)->as.heap.aux.shared->ptr;
  mrb_value ret = mrb_str_new_lit(mrb, "#<");
  mrb_str_cat_str(mrb, ret, mrb_ptr_to_str(mrb, p));
  mrb_str_cat_lit(mrb, ret, " ");
  mrb_str_cat_str(mrb, ret, mrb_inspect(mrb, mrb_str_new_cstr(mrb, p)));
  mrb_str_cat_lit(mrb, ret, ">");
  return ret;
}

static mrb_value
str_internal_inspect(mrb_state *mrb, mrb_value self)
{
  struct RString *s = RSTRING(self);
  mrb_value ret = simple_inspect(mrb, self, "\n");
  INSPECT_INTERNAL(ret, self, "frozen?         ", frozen_p);
  INSPECT_INTERNAL(ret, self, "embedded?       ", embedded_p);
  INSPECT_INTERNAL(ret, self, "shared?         ", shared_p);
  INSPECT_INTERNAL(ret, self, "fshared?        ", fshared_p);
  INSPECT_INTERNAL(ret, self, "nofree?         ", nofree_p);
  INSPECT_INTERNAL(ret, self, "pool?           ", pool_p);
  INSPECT_INTERNAL(ret, self, "ascii?          ", ascii_p);
  INSPECT_INTERNAL(ret, self, "ro_data?        ", ro_data_p);
  INSPECT_INTERNAL(ret, self, "null_terminated?", null_terminated_p);
  INSPECT_INTERNAL(ret, self, "bytesize        ", bytesize);
  if (RSTR_FSHARED_P(s)) {
    INSPECT_INTERNAL(ret, self, "fshared         ", fshared_to_s);
  }
  else if (RSTR_SHARED_P(s)) {
    INSPECT_INTERNAL(ret, self, "shared          ", shared);
    INSPECT_INTERNAL(ret, self, "shared.refcnt   ", shared_reference_count);
    INSPECT_INTERNAL(ret, self, "shared.capa     ", shared_capacity);
    INSPECT_INTERNAL(ret, self, "shared.ptr      ", shared_pointer);
  }
  else {
    INSPECT_INTERNAL(ret, self, "capacity        ", capacity);
  }
  RSTR_SET_LEN(mrb_str_ptr(ret), RSTR_LEN(mrb_str_ptr(ret)) - 1);
  mrb_str_cat_lit(mrb, ret, ">\n");
  return ret;
}

void
mrb_mruby_object_internal_init_string(mrb_state* mrb)
{
  struct RClass *c = mrb->string_class;
  mrb_define_class_method(mrb, c, "embeddable_capacity", str_s_embeddable_capacity, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "embedded?", str_embedded_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "shared?", str_shared_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "fshared?", str_fshared_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "nofree?", str_nofree_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "pool?", str_pool_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "ascii?", str_ascii_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "ro_data?", str_ro_data_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "null_terminated?", str_null_terminated_p, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "capacity", str_capacity, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "fshared", str_fshared, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "shared_capacity", str_shared_capacity, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "shared_reference_count", str_shared_reference_count, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "internal_inspect", str_internal_inspect, MRB_ARGS_NONE());
  mrb_define_method(mrb, c, "ii", str_internal_inspect, MRB_ARGS_NONE());
}
