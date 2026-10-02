// SPDX-License-Identifier: Apache-2.0
import Foundation
public enum PetActivitySort:String,CaseIterable,Sendable {
    case catalog,name,duration,level
    public var title:String { switch self { case .catalog:"默认";case .name:"名称";case .duration:"时长";case .level:"等级要求" } }
}
/// Query only the catalog. Session state and eligibility remain owned by the engine.
public struct PetActivityQuery:Sendable {
    public var search:String
    public var kind:ActivityKind?
    public var favoritesOnly:Bool
    public var sort:PetActivitySort
    public var ascending:Bool
    public init(search:String="",kind:ActivityKind?=nil,favoritesOnly:Bool=false,sort:PetActivitySort = .catalog,ascending:Bool=true) {
        self.search=search;self.kind=kind;self.favoritesOnly=favoritesOnly;self.sort=sort;self.ascending=ascending
    }
    public func evaluate(catalog:PetCatalog,favorites:Set<String>=[]) -> [ActivityDefinition] {
        let needle=search.trimmingCharacters(in:.whitespacesAndNewlines)
        return catalog.activities.enumerated().filter { _,activity in
            (kind == nil || activity.kind == kind) && (!favoritesOnly || favorites.contains(activity.id)) &&
            (needle.isEmpty || activity.name.localizedCaseInsensitiveContains(needle))
        }.sorted { a,b in
            let comparison:ComparisonResult
            switch sort {
            case .catalog: comparison=a.offset<b.offset ? .orderedAscending:a.offset>b.offset ? .orderedDescending:.orderedSame
            case .name: comparison=a.element.name<b.element.name ? .orderedAscending:a.element.name>b.element.name ? .orderedDescending:.orderedSame
            case .duration: comparison=a.element.durationSeconds<b.element.durationSeconds ? .orderedAscending:a.element.durationSeconds>b.element.durationSeconds ? .orderedDescending:.orderedSame
            case .level: comparison=a.element.levelLimit<b.element.levelLimit ? .orderedAscending:a.element.levelLimit>b.element.levelLimit ? .orderedDescending:.orderedSame
            }
            if comparison == .orderedSame { return a.element.id<b.element.id }
            return comparison == (ascending ? .orderedAscending:.orderedDescending)
        }.map(\.element)
    }
}
