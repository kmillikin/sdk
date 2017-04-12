// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library kernel.dataflow.extractor.source_sink_translator;

import '../../ast.dart';
import '../../dataflow/extractor/value_sink.dart';
import '../../dataflow/extractor/value_source.dart';
import '../../dataflow/storage_location.dart';
import '../../dataflow/value.dart';
import '../constraints.dart';
import 'augmented_type.dart';
import 'augmented_hierarchy.dart';
import 'package:kernel/core_types.dart';
import 'package:kernel/dataflow/extractor/common_values.dart';
import 'package:kernel/dataflow/extractor/constraint_builder.dart';

/// Generates constraints from [ValueSource]/[ValueSink] assignments.
class SourceSinkTranslator extends ConstraintBuilder {
  final AugmentedHierarchy hierarchy;
  final ValueLattice lattice;
  final CommonValues common;

  CoreTypes get coreTypes => lattice.coreTypes;

  SourceSinkTranslator(ConstraintSystem constraintSystem, this.hierarchy,
      this.lattice, this.common)
      : super(constraintSystem);

  InterfaceAType getTypeAsInstanceOf(InterfaceAType subtype, Class superclass) {
    return hierarchy.getTypeAsInstanceOf(subtype, superclass);
  }

  void addAssignmentWithFilter(
      ValueSource source, ValueSink sink, TypeFilter filter) {
    addAssignment(source, sink, filter.mask, filter.interfaceClass);
  }

  void addAssignment(ValueSource source, ValueSink sink, int mask,
      [Class interfaceClass]) {
    sink.acceptSink(
        new AssignmentSinkVisitor(this, source, mask, interfaceClass));
  }

  void addAssignmentToLocation(
      ValueSource source, StorageLocation sink, int mask,
      [Class interfaceClass]) {
    source.acceptSource(
        new AssignmentSourceVisitor(this, sink, mask, interfaceClass));
  }

  /// Mark values coming from [source] as escaping.
  ///
  /// The the [guard] is given, only take effect if the guard can lead to
  /// escape.
  void addEscape(ValueSource source, {ValueSink guard}) {
    if (guard != null) {
      guard.acceptSink(new EscapeSinkVisitor(this, source));
    } else {
      source.acceptSource(new EscapeSourceVisitor(this));
    }
  }
}

class AssignmentSinkVisitor extends ValueSinkVisitor {
  final SourceSinkTranslator translator;
  final ValueSource source;
  final int mask;
  final Class interfaceClass;

  AssignmentSinkVisitor(
      this.translator, this.source, this.mask, this.interfaceClass);

  @override
  visitEscapingSink(EscapingSink sink) {
    translator.addEscape(source);
  }

  @override
  visitStorageLocation(StorageLocation sink) {
    translator.addAssignmentToLocation(source, sink, mask, interfaceClass);
  }

  @override
  visitNowhereSink(NowhereSink sink) {}

  @override
  visitUnassignableSink(UnassignableSink sink) {
    throw new UnassignableSinkError(sink);
  }

  @override
  visitValueSinkWithEscape(ValueSinkWithEscape sink) {
    sink.base.acceptSink(this);
    translator.addEscape(source, guard: sink.escaping);
  }
}

class AssignmentSourceVisitor extends ValueSourceVisitor {
  final SourceSinkTranslator translator;
  final StorageLocation sink;
  final int mask;
  final Class interfaceClass;

  CommonValues get common => translator.common;
  CoreTypes get coreTypes => translator.coreTypes;

  AssignmentSourceVisitor(
      this.translator, this.sink, this.mask, this.interfaceClass);

  AssignmentSourceVisitor get nullabilityVisitor {
    if (mask & ~ValueFlags.null_ == 0) return this;
    return new AssignmentSourceVisitor(
        translator, sink, ValueFlags.null_, null);
  }

  @override
  visitStorageLocation(StorageLocation source) {
    if (interfaceClass != null && interfaceClass != coreTypes.objectClass) {
      // Type filters do not work well for 'int' and 'num' because the class
      // _GrowableArrayMarker implements 'int', so use a value filter constraint
      // for those two cases.
      // For the other built-in types we also use value filters, but this is
      // for performance and ensuring that the escape bit is set correctly.
      Value valueFilter;
      if (interfaceClass == coreTypes.intClass) {
        valueFilter = common.nullableIntValue;
      } else if (interfaceClass == coreTypes.numClass) {
        valueFilter = common.nullableNumValue;
      } else if (interfaceClass == coreTypes.doubleClass) {
        valueFilter = common.nullableDoubleValue;
      } else if (interfaceClass == coreTypes.stringClass) {
        valueFilter = common.nullableStringValue;
      } else if (interfaceClass == coreTypes.boolClass) {
        valueFilter = common.nullableBoolValue;
      } else if (interfaceClass == coreTypes.functionClass) {
        valueFilter = common.nullableEscapingFunctionValue;
      }
      if (valueFilter != null) {
        translator.addConstraint(
            new ValueFilterConstraint(source, sink, valueFilter));
      } else {
        translator.addConstraint(
            new TypeFilterConstraint(source, sink, interfaceClass, mask));
      }
    } else {
      translator.addConstraint(new AssignConstraint(source, sink, mask));
    }
  }

  @override
  visitValue(Value value) {
    if (value.flags & mask == 0) return;
    if (interfaceClass != null) {
      value = translator.lattice
          .restrictValueToInterface(value, interfaceClass, mask);
    } else {
      value = value.masked(mask);
    }
    translator.addConstraint(new ValueConstraint(sink, value));
  }

  @override
  visitValueSourceWithNullability(ValueSourceWithNullability source) {
    source.nullability.acceptSource(nullabilityVisitor);
    source.base.acceptSource(this);
  }
}

class EscapeSinkVisitor extends ValueSinkVisitor {
  final SourceSinkTranslator translator;
  final ValueSource source;

  EscapeSinkVisitor(this.translator, this.source);

  @override
  visitEscapingSink(EscapingSink sink) {
    source.acceptSource(new EscapeSourceVisitor(translator));
  }

  @override
  visitNowhereSink(NowhereSink sink) {}

  @override
  visitStorageLocation(StorageLocation sink) {
    source.acceptSource(new EscapeSourceVisitor(translator, guard: sink));
  }

  @override
  visitUnassignableSink(UnassignableSink sink) {}

  @override
  visitValueSinkWithEscape(ValueSinkWithEscape sink) {
    sink.base.acceptSink(this);
    sink.escaping.acceptSink(this);
  }
}

class EscapeSourceVisitor extends ValueSourceVisitor {
  final SourceSinkTranslator translator;
  final StorageLocation guard;

  EscapeSourceVisitor(this.translator, {this.guard});

  @override
  visitStorageLocation(StorageLocation source) {
    translator.addConstraint(new EscapeConstraint(source, guard: guard));
  }

  @override
  visitValue(Value value) {}

  @override
  visitValueSourceWithNullability(ValueSourceWithNullability source) {
    source.base.acceptSource(this);
  }
}

class TypeFilter {
  final Class interfaceClass;
  final int valueSets;

  TypeFilter(this.interfaceClass, this.valueSets);

  int get mask => valueSets | ValueFlags.nonValueSetFlags;

  static final TypeFilter none = new TypeFilter(null, ValueFlags.allValueSets);
}
