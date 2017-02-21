// Copyright (c) 2016, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.
library kernel.inference.extractor.binding;

import '../../ast.dart';
import '../../core_types.dart';
import '../storage_location.dart';
import 'augmented_type.dart';

/// Constructs augmented types and type modifier variables.
class Binding {
  final CoreTypes coreTypes;
  final Map<Class, ClassBank> classBanks = <Class, ClassBank>{};
  final Map<Member, MemberBank> memberBanks = <Member, MemberBank>{};

  Binding(this.coreTypes);

  MemberBank _initializeMemberBank(Member member) {
    if (member is Field) {
      var modifiers = new FieldBank(member, coreTypes);
      modifiers.type = modifiers.augmentType(member.type);
      return modifiers;
    } else {
      var modifiers = new FunctionMemberBank(member, coreTypes);
      var function = member.function;
      modifiers.type = modifiers.augmentType(function.functionType);
      return modifiers;
    }
  }

  ModifierBank _initializeClassBank(Class class_) {
    var modifiers = new ClassBank(class_, coreTypes);
    modifiers.typeParameters = class_.typeParameters
        .map((p) => modifiers.augmentBound(p.bound))
        .toList(growable: false);
    modifiers.supertypes = class_.supers
        .map((s) => modifiers.augmentSuper(s))
        .toList(growable: false);
    return modifiers;
  }

  ClassBank getClassBank(Class class_) {
    return classBanks[class_] ??= _initializeClassBank(class_);
  }

  MemberBank getMemberBank(Member member) {
    return memberBanks[member] ??= _initializeMemberBank(member);
  }

  FieldBank getFieldBank(Field field) {
    return getMemberBank(field);
  }

  FunctionMemberBank getFunctionBank(Member member) {
    return getMemberBank(member);
  }

  List<ASupertype> getSupertypes(Class class_) {
    return getClassBank(class_).supertypes;
  }

  AType getFieldType(Field node) {
    return getFieldBank(node).type;
  }

  AType getGetterType(Member member) {
    if (member is Field) return getFieldType(member);
    if (member is Procedure) {
      var modifiers = getFunctionBank(member);
      return member.isGetter ? modifiers.type.returnType : modifiers.type;
    }
    throw '$member cannot be used as a getter';
  }

  AType getSetterType(Member member) {
    if (member is Field) return getFieldType(member);
    if (member is Procedure && member.isSetter) {
      var modifiers = getFunctionBank(member);
      return modifiers.type.positionalParameters[0];
    }
    throw '$member cannot be used as a setter';
  }
}

abstract class ModifierBank {
  final CoreTypes coreTypes;
  final List<StorageLocation> modifiers = <StorageLocation>[];

  ModifierBank(this.coreTypes);

  TreeNode get classOrMember;

  int get nextIndex => modifiers.length;

  StorageLocation newModifier() {
    var modifier = new StorageLocation(classOrMember, modifiers.length);
    modifiers.add(modifier);
    return modifier;
  }

  Augmentor getAugmentor(int offset) {
    return new AugmentorVisitor(coreTypes, this, offset);
  }

  AType augmentBound(DartType type, [int offset]) {
    return new AugmentorVisitor(coreTypes, this, offset).makeBound(type);
  }

  AType augmentType(DartType type, [int offset]) {
    return new AugmentorVisitor(coreTypes, this, offset).makeType(type);
  }

  List<AType> augmentTypeList(Iterable<DartType> types, [int offset]) {
    return types.map((t) => augmentType(t, offset)).toList(growable: false);
  }

  ASupertype augmentSuper(Supertype type, [int offset]) {
    return new AugmentorVisitor(coreTypes, this, offset).makeSuper(type);
  }

  List<ASupertype> augmentSuperList(Iterable<Supertype> types, [int offset]) {
    return types.map((t) => augmentSuper(t, offset)).toList(growable: false);
  }
}

abstract class MemberBank extends ModifierBank {
  MemberBank(CoreTypes coreTypes) : super(coreTypes);

  AType get type;
}

class FieldBank extends MemberBank {
  final Field field;
  AType type;

  FieldBank(this.field, CoreTypes coreTypes) : super(coreTypes);

  Member get classOrMember => field;
}

class FunctionMemberBank extends MemberBank {
  final Member member;
  FunctionAType type;

  FunctionMemberBank(this.member, CoreTypes coreTypes) : super(coreTypes);

  AType get returnType => type.returnType;
  List<AType> get typeParameters => type.typeParameters;
  List<AType> get positionalParameters => type.positionalParameters;
  List<AType> get namedParameters => type.namedParameters;

  Member get classOrMember => member;
}

class ClassBank extends ModifierBank {
  final Class classNode;
  List<AType> typeParameters;
  List<ASupertype> supertypes;

  ClassBank(this.classNode, CoreTypes coreTypes) : super(coreTypes);

  Class get classOrMember => classNode;
}

abstract class Augmentor {
  int index;
  AType augmentType(DartType type);
  AType augmentBound(DartType type);
}

class AugmentorVisitor extends DartTypeVisitor<AType> implements Augmentor {
  final CoreTypes coreTypes;
  final ModifierBank modifiers;
  final List<List<TypeParameter>> innerTypeParameters = <List<TypeParameter>>[];
  StorageLocation source, sink;
  int index;

  AugmentorVisitor(this.coreTypes, this.modifiers, this.index);

  AType augmentType(DartType type) => makeType(type);

  AType augmentBound(DartType type) => makeBound(type);

  StorageLocation nextModifier() {
    if (index == null) {
      return modifiers.newModifier();
    } else {
      return modifiers.modifiers[index++];
    }
  }

  AType makeType(DartType type) {
    source = sink = nextModifier();
    return type.accept(this);
  }

  AType makeBound(DartType type) {
    source = nextModifier();
    sink = nextModifier();
    return type.accept(this);
  }

  ASupertype makeSuper(Supertype type) {
    return new ASupertype(type.classNode,
        type.typeArguments.map(makeType).toList(growable: false));
  }

  visitInvalidType(InvalidType node) {
    return new InterfaceAType(
        source, sink, coreTypes.objectClass, const <AType>[]);
  }

  visitDynamicType(DynamicType node) {
    return new InterfaceAType(
        source, sink, coreTypes.objectClass, const <AType>[]);
  }

  visitVoidType(VoidType node) {
    return new BottomAType(source, sink);
  }

  visitBottomType(BottomType node) {
    return new BottomAType(source, sink);
  }

  visitInterfaceType(InterfaceType node) {
    return new InterfaceAType(source, sink, node.classNode,
        node.typeArguments.map(makeBound).toList(growable: false));
  }

  visitFunctionType(FunctionType node) {
    innerTypeParameters.add(node.typeParameters);
    var type = new FunctionAType(
        source,
        sink,
        node.typeParameters
            .map((p) => makeBound(p.bound))
            .toList(growable: false),
        node.requiredParameterCount,
        node.positionalParameters.map(makeType).toList(growable: false),
        node.namedParameters.map((t) => t.name).toList(growable: false),
        node.namedParameters
            .map((t) => makeType(t.type))
            .toList(growable: false),
        makeType(node.returnType));
    innerTypeParameters.removeLast();
    return type;
  }

  visitTypeParameterType(TypeParameterType node) {
    for (int i = innerTypeParameters.length - 1; i >= 0; --i) {
      var list = innerTypeParameters[i];
      int index = list.indexOf(node.parameter);
      if (index != -1) {
        return new FunctionTypeParameterAType(source, sink, index);
      }
    }
    source.isNullabilityKey = true;
    sink.isNullabilityKey = true;
    return new TypeParameterAType(source, sink, node.parameter);
  }
}
