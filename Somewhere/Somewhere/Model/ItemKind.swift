//
//  ItemKind.swift
//  Somewhere — what a saved thing actually *is*: "shirt", "jeans", "sneakers".
//
//  ItemCategory is the broad shelf (clothes, bags & shoes, room, beauty).
//  ItemKind is the specific thing, stored on SavedItem.itemType. It's what lets
//  "blue shirt" find a long-sleeve top but NOT a pair of blue jeans — both are
//  "clothes", only one is a shirt.
//
//  Detected from, in order of trust:
//    1. the title           "Zara long-sleeves"          → long-sleeve top
//    2. the page description "Relaxed cotton shirt with…" → shirt
//    3. Vision's labels      "sneaker"                    → sneakers
//    4. screenshot text      (noisy — other products, app chrome)
//  Inside one piece of text the LAST item word wins, because English puts the
//  real noun last: "shirt dress" is a dress, "denim jacket" is a jacket.
//
//  ⚠️ Both targets: the Share Extension sets it at save time, the app's
//     VisualIndexer fills it in for older saves.
//

import Foundation

struct ItemKind: Sendable, Equatable {
    /// Shown in the app and stored in SavedItem.itemType.
    let name: String
    let category: ItemCategory
    /// Words / phrases that mean "this is one of these" in a title or description.
    let words: [String]
    /// Extra words someone might search with: "shoes" finds sneakers.
    let searchWords: [String]

    init(_ name: String, _ category: ItemCategory, _ words: [String], search: [String] = []) {
        self.name = name
        self.category = category
        self.words = words
        self.searchWords = search
    }

    /// Every single word that should find this kind in a search.
    var searchTerms: Set<String> { ItemKind.searchTermsByName[name] ?? [] }

    private static let searchTermsByName: [String: Set<String>] = Dictionary(
        all.map { kind in
            let phrases = [kind.name] + kind.words + kind.searchWords
            return (kind.name, Set(phrases.flatMap { WishlistSearch.tokens(from: $0, dropStopWords: false) }))
        },
        uniquingKeysWith: { a, _ in a }
    )
}

// MARK: - The list

extension ItemKind {

    /// Keep modifiers ("knit", "denim", "cropped") OUT of `words` — they describe
    /// lots of kinds, and a search for "knit dress" must still find a dress.
    static let all: [ItemKind] = [
        // Tops
        ItemKind("t-shirt", .clothes, ["t shirt", "tshirt", "tee", "baby tee", "graphic tee"],
                 search: ["shirt", "top"]),
        ItemKind("long-sleeve top", .clothes, ["long sleeve", "long sleeves", "longsleeve", "long sleeved"],
                 search: ["shirt", "top", "tee"]),
        ItemKind("tank top", .clothes, ["tank", "tank top", "cami", "camisole"], search: ["top"]),
        ItemKind("shirt", .clothes, ["shirt", "button down", "button up", "oxford shirt", "flannel", "overshirt"],
                 search: ["top"]),
        ItemKind("blouse", .clothes, ["blouse"], search: ["shirt", "top"]),
        ItemKind("polo", .clothes, ["polo", "polo shirt"], search: ["shirt", "top"]),
        ItemKind("top", .clothes, ["top", "crop top", "bodysuit", "corset"], search: ["shirt"]),
        ItemKind("sweater", .clothes, ["sweater", "jumper", "pullover", "turtleneck", "knitwear"],
                 search: ["top", "knit"]),
        ItemKind("cardigan", .clothes, ["cardigan"], search: ["sweater", "knit"]),
        ItemKind("sweatshirt", .clothes, ["sweatshirt", "crewneck"], search: ["sweater", "top"]),
        ItemKind("hoodie", .clothes, ["hoodie", "hooded sweatshirt", "zip up"], search: ["sweatshirt", "sweater"]),
        // Outerwear
        ItemKind("jacket", .clothes, ["jacket", "bomber", "windbreaker", "shacket"], search: ["coat"]),
        ItemKind("blazer", .clothes, ["blazer"], search: ["jacket"]),
        ItemKind("coat", .clothes, ["coat", "trench", "overcoat", "parka", "puffer"], search: ["jacket"]),
        ItemKind("vest", .clothes, ["vest", "gilet"]),
        // Bottoms & one-pieces
        ItemKind("jeans", .clothes, ["jeans"], search: ["pants", "denim"]),
        ItemKind("pants", .clothes, ["pants", "trousers", "slacks", "chinos", "joggers", "sweatpants"],
                 search: ["bottoms"]),
        ItemKind("leggings", .clothes, ["leggings"], search: ["pants"]),
        ItemKind("shorts", .clothes, ["shorts"]),
        ItemKind("skirt", .clothes, ["skirt", "skort"]),
        ItemKind("dress", .clothes, ["dress", "gown", "sundress"]),
        ItemKind("jumpsuit", .clothes, ["jumpsuit", "romper", "overalls", "playsuit"]),
        ItemKind("swimsuit", .clothes, ["swimsuit", "bikini", "one piece", "swimwear"], search: ["swim"]),
        ItemKind("pajamas", .clothes, ["pajamas", "pyjamas", "pjs", "loungewear"]),
        ItemKind("socks", .clothes, ["socks", "sock"]),
        // Shoes
        ItemKind("sneakers", .accessories, ["sneaker", "sneakers", "trainers", "running shoes"], search: ["shoes"]),
        ItemKind("heels", .accessories, ["heels", "heel", "pumps", "stilettos", "high heels"], search: ["shoes"]),
        ItemKind("boots", .accessories, ["boots", "boot", "booties"], search: ["shoes"]),
        ItemKind("sandals", .accessories, ["sandals", "sandal", "slides", "flip flops"], search: ["shoes"]),
        ItemKind("flats", .accessories, ["flats", "ballet flats", "ballerina", "ballerinas", "mary jane", "mary janes"],
                 search: ["shoes"]),
        ItemKind("loafers", .accessories, ["loafers", "loafer"], search: ["shoes"]),
        ItemKind("shoes", .accessories, ["shoes", "shoe"]),
        // Bags & small things
        ItemKind("tote bag", .accessories, ["tote", "tote bag"], search: ["bag"]),
        ItemKind("backpack", .accessories, ["backpack"], search: ["bag"]),
        ItemKind("bag", .accessories, ["bag", "handbag", "purse", "shoulder bag", "crossbody", "clutch"],
                 search: ["purse", "handbag"]),
        ItemKind("wallet", .accessories, ["wallet", "card holder", "cardholder"]),
        ItemKind("necklace", .accessories, ["necklace", "pendant", "choker"], search: ["jewelry"]),
        ItemKind("earrings", .accessories, ["earrings", "earring", "hoops", "studs"], search: ["jewelry"]),
        ItemKind("ring", .accessories, ["ring"], search: ["jewelry"]),
        ItemKind("bracelet", .accessories, ["bracelet", "bangle", "cuff"], search: ["jewelry"]),
        ItemKind("watch", .accessories, ["watch"]),
        ItemKind("hat", .accessories, ["hat", "cap", "beanie", "bucket hat", "beret"]),
        ItemKind("scarf", .accessories, ["scarf"]),
        ItemKind("belt", .accessories, ["belt"]),
        ItemKind("sunglasses", .accessories, ["sunglasses"], search: ["glasses"]),
        ItemKind("glasses", .accessories, ["glasses", "eyeglasses", "frames"]),
        ItemKind("hair accessory", .accessories, ["claw clip", "hair clip", "scrunchie", "headband", "hair bow"],
                 search: ["hair", "clip"]),
        // Room
        ItemKind("lamp", .room, ["lamp"]),
        ItemKind("rug", .room, ["rug", "carpet"]),
        ItemKind("pillow", .room, ["pillow", "cushion"]),
        ItemKind("blanket", .room, ["blanket"]),
        ItemKind("bedding", .room, ["bedding", "duvet", "sheets", "comforter", "quilt"]),
        ItemKind("mirror", .room, ["mirror"]),
        ItemKind("chair", .room, ["chair", "armchair", "stool"]),
        ItemKind("sofa", .room, ["sofa", "couch"]),
        ItemKind("desk", .room, ["desk"]),
        ItemKind("shelf", .room, ["shelf", "shelves", "bookshelf", "bookcase"]),
        ItemKind("candle", .room, ["candle"]),
        ItemKind("vase", .room, ["vase"]),
        ItemKind("art print", .room, ["poster", "art print", "wall art"], search: ["print", "art"]),
        ItemKind("plant", .room, ["plant", "planter"]),
        ItemKind("mug", .room, ["mug"], search: ["cup"]),
        // Beauty
        ItemKind("lip product", .beauty, ["lipstick", "lip gloss", "lip oil", "lip balm", "lip tint", "lip liner"],
                 search: ["lip", "lips", "gloss", "makeup"]),
        ItemKind("perfume", .beauty, ["perfume", "fragrance", "eau de parfum", "eau de toilette", "cologne", "body mist"]),
        ItemKind("serum", .beauty, ["serum"], search: ["skincare"]),
        ItemKind("moisturizer", .beauty, ["moisturizer", "moisturiser", "face cream"], search: ["skincare"]),
        ItemKind("sunscreen", .beauty, ["sunscreen", "spf"], search: ["skincare"]),
        ItemKind("cleanser", .beauty, ["cleanser", "face wash"], search: ["skincare"]),
        ItemKind("foundation", .beauty, ["foundation", "concealer", "skin tint"], search: ["makeup"]),
        ItemKind("mascara", .beauty, ["mascara"], search: ["makeup"]),
        ItemKind("eyeshadow", .beauty, ["eyeshadow", "eye shadow", "palette"], search: ["makeup"]),
        ItemKind("nail polish", .beauty, ["nail polish", "nail"], search: ["nails"]),
        ItemKind("hair care", .beauty, ["shampoo", "conditioner", "hair oil", "hair mask"], search: ["hair"]),
    ]

    static let byName: [String: ItemKind] = Dictionary(all.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })

    /// Single words that name a kind ("shirt", "jeans", "tote"). A search token
    /// in here has to agree with an item's kind when the kind is known.
    static let kindWords: Set<String> = {
        var words = Set<String>()
        for kind in all {
            for phrase in kind.words + [kind.name] {
                let parts = WishlistSearch.tokens(from: phrase, dropStopWords: false)
                if parts.count == 1 { words.insert(parts[0]) }
            }
        }
        return words
    }()

    /// Vision labels (VNClassifyImageRequest) that name a kind outright.
    /// "clothing" and "jeans" are left out on purpose: a model wearing jeans
    /// under the T-shirt you saved gets labelled "jeans" too.
    static let forVisionLabel: [String: String] = [
        "jacket": "jacket", "hoodie": "hoodie", "swimsuit": "swimsuit", "wedding_dress": "dress",
        "sneaker": "sneakers", "high_heel": "heels", "boot": "boots", "sandal": "sandals",
        "bag": "bag", "purse": "bag", "wallet": "wallet", "scarf": "scarf",
        "sunglasses": "sunglasses", "eyeglasses": "glasses", "watch": "watch",
        "hat": "hat", "baseball_hat": "hat", "sunhat": "hat",
        "sofa": "sofa", "armchair": "chair", "chair": "chair", "lamp": "lamp", "pillow": "pillow",
        "vase": "vase", "candle": "candle", "mug": "mug", "bedding": "bedding",
    ]
}

// MARK: - Detection

extension ItemKind {

    /// Best guess at what this is. Each source is only used if the ones before it found nothing.
    static func detect(
        title: String?,
        description: String? = nil,
        visionLabels: [(name: String, confidence: Float)] = [],
        recognizedText: String? = nil
    ) -> ItemKind? {
        if let kind = lastKind(in: title) { return kind }
        if let kind = lastKind(in: description.map { String($0.prefix(300)) }) { return kind }
        if let kind = fromVision(visionLabels) { return kind }
        return lastKind(in: recognizedText)
    }

    /// The kind whose word appears LAST in the text (the head noun).
    /// Ties at the same spot go to the longer phrase: "tote bag" beats "bag".
    static func lastKind(in text: String?) -> ItemKind? {
        guard let text, !text.isEmpty else { return nil }
        let haystack = " " + WishlistSearch.normalize(text) + " "

        var best: (kind: ItemKind, end: String.Index, length: Int)?
        for kind in all {
            for word in kind.words {
                let phrase = WishlistSearch.normalize(word)
                for form in [phrase, phrase + "s", phrase + "es"] {
                    guard let range = haystack.range(of: " " + form + " ", options: .backwards) else { continue }
                    let end = range.upperBound
                    if best == nil || end > best!.end || (end == best!.end && form.count > best!.length) {
                        best = (kind, end, form.count)
                    }
                }
            }
        }
        return best?.kind
    }

    private static func fromVision(_ labels: [(name: String, confidence: Float)]) -> ItemKind? {
        let best = labels
            .filter { $0.confidence >= 0.5 && forVisionLabel[$0.name] != nil }
            .max { $0.confidence < $1.confidence }
        return best.flatMap { forVisionLabel[$0.name] }.flatMap { byName[$0] }
    }
}

// MARK: - On the item

extension SavedItem {
    /// nil when we couldn't tell (or for items saved before kinds existed).
    var kind: ItemKind? { itemType.flatMap { ItemKind.byName[$0] } }
}
