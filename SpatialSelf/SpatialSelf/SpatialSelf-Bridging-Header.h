//
//  SpatialSelf-Bridging-Header.h
//  Exposes the Self VM's C entry points (self_vm_main,
//  self_vm_set_io_fds) to Swift. The header itself ships inside
//  Self.xcframework; alternatively point SWIFT_OBJC_BRIDGING_HEADER at
//  vm64/build_support/embed/self_vm.h directly.
//

#import "self_vm.h"
