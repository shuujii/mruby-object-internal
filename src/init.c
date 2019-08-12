#include <mruby.h>

void mrb_mruby_object_internal_init_string(mrb_state *mrb);

void
mrb_mruby_object_internal_gem_init(mrb_state* mrb)
{
  mrb_mruby_object_internal_init_string(mrb); mrb_gc_arena_restore(mrb, 0);
}

void
mrb_mruby_object_internal_gem_final(mrb_state* mrb)
{
}
