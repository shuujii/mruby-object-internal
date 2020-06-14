#include <mruby.h>
#include <mruby/hash.h>

static mrb_value
hash_s_new_with_capacity(mrb_state *mrb, mrb_value klass)
{
  mrb_int capa;
  mrb_get_args(mrb, "i", &capa);
  return mrb_hash_new_capa(mrb, capa);
}

static mrb_value
hash_s_merge(mrb_state *mrb, mrb_value klass)
{
  mrb_value hash1, hash2;
  mrb_get_args(mrb, "HH", &hash1, &hash2);
  mrb_hash_merge(mrb, hash1, hash2);
  return hash1;
}

void
mrb_mruby_object_internal_test_hash(mrb_state* mrb)
{
  struct RClass *c = mrb_define_class(mrb, "HashTest", mrb->object_class);
  mrb_define_class_method(mrb, c, "new_with_capacity", hash_s_new_with_capacity, MRB_ARGS_REQ(1));
  mrb_define_class_method(mrb, c, "merge", hash_s_merge, MRB_ARGS_REQ(2));
}
