// SPDX-License-Identifier: Apache-2.0
import Foundation
public enum PetInventorySort:String,CaseIterable,Sendable {
    case catalog,name,quantity,price
    public var title:String { switch self { case .catalog:"默认";case .name:"名称";case .quantity:"数量";case .price:"单价" } }
}
public struct PetInventoryResult:Sendable {
    public let ids:[String]
    public let totalCount:Int
    public let knownValue:Double
    public let unpricedCount:Int
}
public struct PetInventoryQuery:Sendable {
    public var search:String
    public var category:ItemCategory?
    public var favoritesOnly:Bool
    public var sort:PetInventorySort
    public var ascending:Bool
    public init(search:String="",category:ItemCategory?=nil,favoritesOnly:Bool=false,sort:PetInventorySort = .catalog,ascending:Bool=true) {
        self.search=search;self.category=category;self.favoritesOnly=favoritesOnly;self.sort=sort;self.ascending=ascending
    }
    public func evaluate(inventory:[String:Int],catalog:PetCatalog,favorites:Set<String>=[],metadata:[String:PetInventoryMetadata]=[:]) -> PetInventoryResult {
        var items=Dictionary(uniqueKeysWithValues:catalog.items.map { ($0.id,$0) })
        for (id,owned) in metadata { items[id]=owned.definition(id:id) }
        let order=Dictionary(uniqueKeysWithValues:catalog.items.enumerated().map { ($0.element.id,$0.offset) })
        let all=inventory.keys.filter { inventory[$0,default:0]>0 }
        let needle=search.trimmingCharacters(in:.whitespacesAndNewlines)
        let ids=all.filter { id in
            metadata[id]?.visibility != false && (!favoritesOnly || favorites.contains(id) || metadata[id]?.star == true) && (category == nil || items[id]?.category == category) &&
            (needle.isEmpty || (items[id]?.name ?? id).localizedCaseInsensitiveContains(needle))
        }.sorted { a,b in
            var comparison:ComparisonResult = .orderedSame
            switch sort {
            case .catalog:
                let x=order[a,default:Int.max],y=order[b,default:Int.max]
                comparison=x<y ? .orderedAscending:x>y ? .orderedDescending:.orderedSame
            case .name:
                // Unknown IDs remain inspectable after named catalog entries.
                if (items[a] == nil) != (items[b] == nil) { return items[a] != nil }
                let x=items[a]?.name ?? a,y=items[b]?.name ?? b
                comparison=x<y ? .orderedAscending:x>y ? .orderedDescending:.orderedSame
            case .quantity:
                let x=inventory[a,default:0],y=inventory[b,default:0]
                comparison=x<y ? .orderedAscending:x>y ? .orderedDescending:.orderedSame
            case .price:
                let x=items[a]?.price ?? 0,y=items[b]?.price ?? 0
                comparison=x<y ? .orderedAscending:x>y ? .orderedDescending:.orderedSame
            }
            if comparison == .orderedSame { return a<b }
            return comparison == (ascending ? .orderedAscending:.orderedDescending)
        }
        return PetInventoryResult(ids:ids,totalCount:all.reduce(0) { $0+inventory[$1,default:0] },knownValue:all.reduce(0) { $0+(items[$1]?.price ?? 0)*Double(inventory[$1,default:0]) },unpricedCount:all.filter { items[$0] == nil }.reduce(0) { $0+inventory[$1,default:0] })
    }
}
