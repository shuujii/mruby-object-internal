#include <mruby.h>
#include <mruby/hash.h>
#include <mruby/array.h>

static int
h_to_a_by_foreach_i(mrb_state *mrb, mrb_value key, mrb_value val, void *data)
{
  mrb_value *entriesp = (mrb_value*)data;
  mrb_ary_push(mrb, *entriesp, mrb_assoc_new(mrb, key, val));
  return 0;
}

static mrb_value
hash_s_new_with_capacity(mrb_state *mrb, mrb_value klass)
{
  mrb_int capa;
  mrb_get_args(mrb, "i", &capa);
  return mrb_hash_new_capa(mrb, capa);
}

static mrb_value
hash_s_to_a_by_foreach(mrb_state *mrb, mrb_value klass)
{
  mrb_value hash, entries;
  mrb_get_args(mrb, "H", &hash);
  entries = mrb_ary_new_capa(mrb, mrb_hash_size(mrb, hash));
  mrb_hash_foreach(mrb, mrb_hash_ptr(hash), h_to_a_by_foreach_i, &entries);
  return entries;
}

static mrb_value
hash_s_dup(mrb_state *mrb, mrb_value klass)
{
  mrb_value hash;
  mrb_get_args(mrb, "H", &hash);
  return mrb_hash_dup(mrb, hash);
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
  mrb_define_class_method(mrb, c, "to_a_by_foreach", hash_s_to_a_by_foreach, MRB_ARGS_REQ(1));
  mrb_define_class_method(mrb, c, "dup!", hash_s_dup, MRB_ARGS_REQ(1));
  mrb_define_class_method(mrb, c, "merge", hash_s_merge, MRB_ARGS_REQ(2));
}
