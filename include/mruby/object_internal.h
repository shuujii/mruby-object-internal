#ifndef MRUBY_OBJECT_INTERNAL_H
#define MRUBY_OBJECT_INTERNAL_H

#include <mruby/common.h>
#include <mruby/string.h>

MRB_INLINE mrb_value
mrb_obj_internal_ptr_to_str(mrb_state *mrb, void *ptr)
{
  mrb_value ret = mrb_str_new_lit(mrb, "#<");
  if (ptr) {
    mrb_str_cat_str(mrb, ret, mrb_ptr_to_str(mrb, ptr));
  }
  else {
    mrb_str_cat_lit(mrb, ret, "null");
  }
  return mrb_str_cat_lit(mrb, ret, ">");
}

#endif  /* MRUBY_OBJECT_INTERNAL_H */
