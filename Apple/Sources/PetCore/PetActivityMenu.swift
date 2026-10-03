// SPDX-License-Identifier: Apache-2.0
/// A shared snapshot gate; native actions recompute it before execution.
public struct PetActivityMenuAccess:Sendable {
    public let allowsSelection:Bool
    public init(writable:Bool,saveFailed:Bool,busy:Bool,simulationEnabled:Bool,visible:Bool,suspended:Bool) {
        allowsSelection=writable && !saveFailed && !busy && simulationEnabled && visible && !suspended
    }
}
public struct PetActivityMenuItem:Identifiable,Sendable {
    public let id,name:String
    public let kind:ActivityKind
    public let levelLimit:Int
    public let isCurrent,isEnabled:Bool
}
public enum PetActivityMenu {
    public static func items(catalog:PetCatalog,state:PetState,enabled:Bool)->[PetActivityMenuItem] {
        catalog.activities.map {
            PetActivityMenuItem(id:$0.id,name:$0.name,kind:$0.kind,levelLimit:$0.levelLimit,
                                isCurrent:state.activity?.activityID == $0.id,
                                isEnabled:enabled && state.mood != .ill && state.level >= $0.levelLimit)
        }
    }
}
