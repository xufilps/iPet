// SPDX-License-Identifier: Apache-2.0
/// VPet 1a06c598 Food.RealPrice/IsOverLoad and MainWindow's food normalization.
public enum PetItemPricing {
    public static func recommendedPrice(_ item:ItemDefinition)->Double {
        ((item.experience/3).rounded(.towardZero)+item.strength/5+item.drink/3+item.food/2+item.feeling/6)/3+item.health+item.affection*10
    }
    public static func isUnderpriced(_ item:ItemDefinition)->Bool {
        item.price < (recommendedPrice(item)-10)*0.7
    }
    public static func catalog(_ source:PetCatalog,enabled:Bool) throws -> PetCatalog {
        try source.validate()
        var result=source
        if enabled {
            result.items=try source.items.map { item in
                guard Int32(exactly:item.experience) != nil else { throw PetSaveError.invalidDocument }
                var item=item
                if isUnderpriced(item) {
                    // Upstream casts to a C# int. Reject values outside its supported range.
                    guard let price=Int32(exactly:recommendedPrice(item).rounded(.towardZero)) else { throw PetSaveError.invalidDocument }
                    item.price=Double(max(price,1))
                }
                return item
            }
        }
        // Reject unsafe results without publishing a partially adjusted catalog.
        try result.validate()
        return result
    }
}
