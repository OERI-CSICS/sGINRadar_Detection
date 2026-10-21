add_executable(xapp_spec_classify
  xapp_spec_classify.c
  ../../../../src/util/alg_ds/alg/defer.c
  )

 target_link_libraries(xapp_spec_classify
 						PUBLIC
 						e42_xapp
 						-pthread
 						-lsctp
 						-ldl
 						)

