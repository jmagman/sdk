// Copyright (c) 2019, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/src/error/codes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import '../dart/resolution/driver_resolution.dart';
import '../dart/resolution/with_null_safety_mixin.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MixinSuperClassConstraintNonInterfaceTest);
    defineReflectiveTests(MixinSuperClassConstraintNonInterfaceWithNnbdTest);
  });
}

@reflectiveTest
class MixinSuperClassConstraintNonInterfaceTest extends DriverResolutionTest {}

@reflectiveTest
class MixinSuperClassConstraintNonInterfaceWithNnbdTest
    extends MixinSuperClassConstraintNonInterfaceTest with WithNullSafetyMixin {
  test_Never() async {
    await assertErrorsInCode('''
mixin M on Never {}
''', [
      error(CompileTimeErrorCode.MIXIN_SUPER_CLASS_CONSTRAINT_NON_INTERFACE, 11,
          5),
    ]);
  }
}
