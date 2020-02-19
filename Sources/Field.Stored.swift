//
//  Field.Stored.swift
//  CoreStore
//
//  Copyright © 2020 John Rommel Estropia
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import CoreData
import Foundation


// MARK: - FieldContainer

extension FieldContainer {

    // MARK: - Stored

    /**
     The containing type for stored property values. Any type that conforms to `FieldStorableType` are supported.
     ```
     class Animal: CoreStoreObject {
         @Field.Stored("species")
         var species = ""

         @Field.Virtual("pluralName", customGetter: Animal.pluralName(_:))
         var pluralName: String = ""

         @Field.Coded("color", coder: FieldCoders.Plist.self)
         var color: UIColor?
     }
     ```
     - Important: `Field` properties are required to be used as `@propertyWrapper`s. Any other declaration not using the `@Field.Stored(...) var` syntax will be ignored.     
     */
    @propertyWrapper
    public struct Stored<V: FieldStorableType>: AttributeKeyPathStringConvertible, FieldAttributeProtocol {

        /**
         Initializes the metadata for the property.
         ```
         class Person: CoreStoreObject {
             @Field.Stored("title")
             var title: String = "Mr."

             @Field.Stored("name")
             var name: String = ""

             @Field.Virtual(
                 "displayName",
                 customGetter: { (object, field) in
                     return "\(object.$title.value) \(object.$name.value)"
                 }
             )
             var displayName: String = ""
         }
         ```
         - parameter initial: the initial value for the property when the object is first create
         - parameter keyPath: the permanent attribute name for this property.
         - parameter versionHashModifier: used to mark or denote a property as being a different "version" than another even if all of the values which affect persistence are equal. (Such a difference is important in cases where the properties are unchanged but the format or content of its data are changed.)
         - parameter previousVersionKeyPath: used to resolve naming conflicts between models. When creating an entity mapping between entities in two managed object models, a source entity property's `keyPath` with a matching destination entity property's `previousVersionKeyPath` indicate that a property mapping should be configured to migrate from the source to the destination. If unset, the identifier will be the property's `keyPath`.
         - parameter customGetter: use this closure as an "override" for the default property getter. The closure receives a `ObjectProxy<O>`, which acts as a fast, type-safe KVC interface for `CoreStoreObject`. The reason a `CoreStoreObject` instance is not passed directly is because the Core Data runtime is not aware of `CoreStoreObject` properties' static typing, and so loading those info everytime KVO invokes this accessor method incurs a cumulative performance hit (especially in KVO-heavy operations such as `ListMonitor` observing.) When accessing the property value from `ObjectProxy<O>`, make sure to use `ObjectProxy<O>.primitiveValue(for:)` instead of `ObjectProxy<O>.value(for:)`, which would unintentionally execute the same closure again recursively.
         - parameter customSetter: use this closure as an "override" for the default property setter. The closure receives a `ObjectProxy<O>`, which acts as a fast, type-safe KVC interface for `CoreStoreObject`. The reason a `CoreStoreObject` instance is not passed directly is because the Core Data runtime is not aware of `CoreStoreObject` properties' static typing, and so loading those info everytime KVO invokes this accessor method incurs a cumulative performance hit (especially in KVO-heavy operations such as `ListMonitor` observing.) When accessing the property value from `ObjectProxy<O>`, make sure to use `ObjectProxy<O>.$property.primitiveValue` instead of `ObjectProxy<O>.$property.value`, which would unintentionally execute the same closure again recursively.
         - parameter affectedByKeyPaths: a set of key paths for properties whose values affect the value of the receiver. This is similar to `NSManagedObject.keyPathsForValuesAffectingValue(forKey:)`.
         */
        public init(
            wrappedValue initial: @autoclosure @escaping () -> V,
            _ keyPath: KeyPathString,
            versionHashModifier: @autoclosure @escaping () -> String? = nil,
            previousVersionKeyPath: @autoclosure @escaping () -> String? = nil,
            customGetter: ((_ object: ObjectProxy<O>, _ field: ObjectProxy<O>.FieldProxy<V>) -> V)? = nil,
            customSetter: ((_ object: ObjectProxy<O>, _ field: ObjectProxy<O>.FieldProxy<V>, _ newValue: V) -> Void)? = nil,
            affectedByKeyPaths: @autoclosure @escaping () -> Set<KeyPathString> = []
        ) {

            self.init(
                wrappedValue: initial,
                keyPath: keyPath,
                isOptional: false,
                versionHashModifier: versionHashModifier,
                renamingIdentifier: previousVersionKeyPath,
                customGetter: customGetter,
                customSetter: customSetter,
                affectedByKeyPaths: affectedByKeyPaths
            )
        }


        // MARK: @propertyWrapper

        @available(*, unavailable)
        public var wrappedValue: V {

            get { fatalError() }
            set { fatalError() }
        }

        public var projectedValue: Self {

            return self
        }

        public static subscript(
            _enclosingInstance instance: O,
            wrapped wrappedKeyPath: ReferenceWritableKeyPath<O, V>,
            storage storageKeyPath: ReferenceWritableKeyPath<O, Self>
        ) -> V {

            get {

                Internals.assert(
                    instance.rawObject != nil,
                    "Attempted to access values from a \(Internals.typeName(O.self)) meta object. Meta objects are only used for querying keyPaths and infering types."
                )
                return self.read(field: instance[keyPath: storageKeyPath], for: instance.rawObject!) as! V
            }
            set {

                Internals.assert(
                    instance.rawObject != nil,
                    "Attempted to access values from a \(Internals.typeName(O.self)) meta object. Meta objects are only used for querying keyPaths and infering types."
                )
                return self.modify(field: instance[keyPath: storageKeyPath], for: instance.rawObject!, newValue: newValue)
            }
        }


        // MARK: AnyKeyPathStringConvertible

        public var cs_keyPathString: String {

            return self.keyPath
        }


        // MARK: KeyPathStringConvertible

        public typealias ObjectType = O
        public typealias DestinationValueType = V


        // MARK: AttributeKeyPathStringConvertible

        public typealias ReturnValueType = DestinationValueType


        // MARK: PropertyProtocol

        internal let keyPath: KeyPathString


        // MARK: FieldProtocol

        internal static func read(field: FieldProtocol, for rawObject: CoreStoreManagedObject) -> Any? {

            Internals.assert(
                rawObject.isRunningInAllowedQueue() == true,
                "Attempted to access \(Internals.typeName(O.self))'s value outside it's designated queue."
            )
            let field = field as! Self
            if let customGetter = field.customGetter {

                return customGetter(
                    ObjectProxy<O>(rawObject),
                    ObjectProxy<O>.FieldProxy<V>(rawObject: rawObject, field: field)
                )
            }
            let keyPath = field.keyPath
            switch rawObject.value(forKey: keyPath) {

            case let rawValue as V.FieldStoredNativeType:
                return V.cs_fromFieldStoredNativeType(rawValue)

            default:
                return nil
            }
        }

        internal static func modify(field: FieldProtocol, for rawObject: CoreStoreManagedObject, newValue: Any?) {

            Internals.assert(
                rawObject.isRunningInAllowedQueue() == true,
                "Attempted to access \(Internals.typeName(O.self))'s value outside it's designated queue."
            )
            Internals.assert(
                rawObject.isEditableInContext() == true,
                "Attempted to update a \(Internals.typeName(O.self))'s value from outside a transaction."
            )
            let newValue = newValue as! V
            let field = field as! Self
            let keyPath = field.keyPath
            if let customSetter = field.customSetter {

                return customSetter(
                    ObjectProxy<O>(rawObject),
                    ObjectProxy<O>.FieldProxy<V>(rawObject: rawObject, field: field),
                    newValue
                )
            }
            return rawObject.setValue(
                newValue.cs_toFieldStoredNativeType(),
                forKey: keyPath
            )
        }


        // MARK: FieldAttributeProtocol

        internal let entityDescriptionValues: () -> FieldAttributeProtocol.EntityDescriptionValues

        internal var getter: CoreStoreManagedObject.CustomGetter? {

            guard let customGetter = self.customGetter else {

                return nil
            }
            let keyPath = self.keyPath
            return { (_ id: Any) -> Any? in

                let rawObject = id as! CoreStoreManagedObject
                rawObject.willAccessValue(forKey: keyPath)
                defer {

                    rawObject.didAccessValue(forKey: keyPath)
                }
                let value = customGetter(
                    ObjectProxy<O>(rawObject),
                    ObjectProxy<O>.FieldProxy<V>(rawObject: rawObject, field: self)
                )
                return value.cs_toFieldStoredNativeType()
            }
        }

        internal var setter: CoreStoreManagedObject.CustomSetter? {

            guard let customSetter = self.customSetter else {

                return nil
            }
            let keyPath = self.keyPath
            return { (_ id: Any, _ newValue: Any?) -> Void in

                let rawObject = id as! CoreStoreManagedObject
                rawObject.willChangeValue(forKey: keyPath)
                defer {

                    rawObject.didChangeValue(forKey: keyPath)
                }
                customSetter(
                    ObjectProxy<O>(rawObject),
                    ObjectProxy<O>.FieldProxy<V>(rawObject: rawObject, field: self),
                    V.cs_fromFieldStoredNativeType(newValue as! V.FieldStoredNativeType)
                )
            }
        }


        // MARK: FilePrivate

        fileprivate init(
            wrappedValue initial: @escaping () -> V,
            keyPath: KeyPathString,
            isOptional: Bool,
            versionHashModifier: @escaping () -> String?,
            renamingIdentifier: @escaping () -> String?,
            customGetter: ((_ object: ObjectProxy<O>, _ field: ObjectProxy<O>.FieldProxy<V>) -> V)?,
            customSetter: ((_ object: ObjectProxy<O>, _ field: ObjectProxy<O>.FieldProxy<V>, _ newValue: V) -> Void)? ,
            affectedByKeyPaths: @escaping () -> Set<KeyPathString>) {

            self.keyPath = keyPath
            self.entityDescriptionValues = {
                (
                    attributeType: V.cs_rawAttributeType,
                    isOptional: isOptional,
                    isTransient: false,
                    allowsExternalBinaryDataStorage: false,
                    versionHashModifier: versionHashModifier(),
                    renamingIdentifier: renamingIdentifier(),
                    valueTransformer: nil,
                    affectedByKeyPaths: affectedByKeyPaths(),
                    defaultValue: initial().cs_toFieldStoredNativeType()
                )
            }
            self.customGetter = customGetter
            self.customSetter = customSetter
        }


        // MARK: Private

        private let customGetter: ((_ object: ObjectProxy<O>, _ field: ObjectProxy<O>.FieldProxy<V>) -> V)?
        private let customSetter: ((_ object: ObjectProxy<O>, _ field: ObjectProxy<O>.FieldProxy<V>, _ newValue: V) -> Void)?
    }
}


// MARK: - FieldContainer.Stored where V: FieldOptionalType

extension FieldContainer.Stored where V: FieldOptionalType {

    /**
     Initializes the metadata for the property.
     ```
     class Person: CoreStoreObject {
         @Field.Stored("title")
         var title: String = "Mr."

         @Field.Stored("name")
         var name: String = ""

         @Field.Virtual("displayName", customGetter: Person.getName(_:))
         var displayName: String = ""

         private static func getName(_ object: ObjectProxy<Person>) -> String {
             let cachedDisplayName = object.primitiveValue(for: \.$displayName)
             if !cachedDisplayName.isEmpty {
                 return cachedDisplayName
             }
             let title = object.value(for: \.$title)
             let name = object.value(for: \.$name)
             let displayName = "\(title) \(name)"
             object.setPrimitiveValue(displayName, for: { $0.displayName })
             return displayName
         }
     }
     ```
     - parameter initial: the initial value for the property when the object is first create
     - parameter keyPath: the permanent attribute name for this property.
     - parameter versionHashModifier: used to mark or denote a property as being a different "version" than another even if all of the values which affect persistence are equal. (Such a difference is important in cases where the properties are unchanged but the format or content of its data are changed.)
     - parameter previousVersionKeyPath: used to resolve naming conflicts between models. When creating an entity mapping between entities in two managed object models, a source entity property's `keyPath` with a matching destination entity property's `previousVersionKeyPath` indicate that a property mapping should be configured to migrate from the source to the destination. If unset, the identifier will be the property's `keyPath`.
     - parameter customGetter: use this closure as an "override" for the default property getter. The closure receives a `ObjectProxy<O>`, which acts as a fast, type-safe KVC interface for `CoreStoreObject`. The reason a `CoreStoreObject` instance is not passed directly is because the Core Data runtime is not aware of `CoreStoreObject` properties' static typing, and so loading those info everytime KVO invokes this accessor method incurs a cumulative performance hit (especially in KVO-heavy operations such as `ListMonitor` observing.) When accessing the property value from `ObjectProxy<O>`, make sure to use `ObjectProxy<O>.primitiveValue(for:)` instead of `ObjectProxy<O>.value(for:)`, which would unintentionally execute the same closure again recursively.
     - parameter customSetter: use this closure as an "override" for the default property setter. The closure receives a `ObjectProxy<O>`, which acts as a fast, type-safe KVC interface for `CoreStoreObject`. The reason a `CoreStoreObject` instance is not passed directly is because the Core Data runtime is not aware of `CoreStoreObject` properties' static typing, and so loading those info everytime KVO invokes this accessor method incurs a cumulative performance hit (especially in KVO-heavy operations such as `ListMonitor` observing.) When accessing the property value from `ObjectProxy<O>`, make sure to use `ObjectProxy<O>.$property.primitiveValue` instead of `ObjectProxy<O>.$property.value`, which would unintentionally execute the same closure again recursively.
     - parameter affectedByKeyPaths: a set of key paths for properties whose values affect the value of the receiver. This is similar to `NSManagedObject.keyPathsForValuesAffectingValue(forKey:)`.
     */
    public init(
        wrappedValue initial: @autoclosure @escaping () -> V = nil,
        _ keyPath: KeyPathString,
        versionHashModifier: @autoclosure @escaping () -> String? = nil,
        previousVersionKeyPath: @autoclosure @escaping () -> String? = nil,
        customGetter: ((_ object: ObjectProxy<O>, _ field: ObjectProxy<O>.FieldProxy<V>) -> V)? = nil,
        customSetter: ((_ object: ObjectProxy<O>, _ field: ObjectProxy<O>.FieldProxy<V>, _ newValue: V) -> Void)? = nil,
        affectedByKeyPaths: @autoclosure @escaping () -> Set<KeyPathString> = []) {

        self.init(
            wrappedValue: initial,
            keyPath: keyPath,
            isOptional: true,
            versionHashModifier: versionHashModifier,
            renamingIdentifier: previousVersionKeyPath,
            customGetter: customGetter,
            customSetter: customSetter,
            affectedByKeyPaths: affectedByKeyPaths
        )
    }
}
