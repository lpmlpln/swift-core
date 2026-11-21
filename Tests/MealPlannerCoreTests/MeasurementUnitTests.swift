import Testing
import Foundation
@testable import MealPlannerCore

@Suite("MeasurementUnit and conversion")
struct MeasurementUnitTests {
    @Test("Parses common spellings")
    func parsing() {
        #expect(MeasurementUnit.parse("Grams") == .gram)
        #expect(MeasurementUnit.parse(" tbsp ") == .tablespoon)
        #expect(MeasurementUnit.parse("fl. oz.") == .fluidOunce)
        #expect(MeasurementUnit.parse("cups") == .cup)
        #expect(MeasurementUnit.parse("furlongs") == nil)
    }

    @Test("Classifies dimensions")
    func dimensions() {
        #expect(MeasurementUnit.kilogram.dimension == .mass)
        #expect(MeasurementUnit.cup.dimension == .volume)
        #expect(MeasurementUnit.clove.dimension == .count)
        #expect(MeasurementUnit.toTaste.dimension == .qualitative)
        #expect(MeasurementUnit.unknown.dimension == .unknown)
    }

    @Test("Converts within a dimension")
    func conversion() throws {
        let kgToG = try #require(UnitConverter.convert(2, from: .kilogram, to: .gram))
        #expect(kgToG == 2_000)

        let cupsToMl = try #require(UnitConverter.convert(1, from: .cup, to: .milliliter))
        #expect(abs(cupsToMl - Decimal(string: "236.5882365")!) < Decimal(string: "0.0001")!)
    }

    @Test("Refuses cross-dimension conversion")
    func crossDimension() {
        #expect(UnitConverter.convert(1, from: .cup, to: .gram) == nil)
        #expect(UnitConverter.canConvert(.pound, .ounce))
        #expect(!UnitConverter.canConvert(.pound, .liter))
    }

    @Test("Normalizes ingredient names")
    func normalization() {
        #expect(IngredientNormalizer.normalize("  Roma Tomatoes ") == "roma tomato")
        #expect(IngredientNormalizer.normalize("Bell-Peppers") == "bell pepper")
        #expect(IngredientNormalizer.normalize("Rice") == "rice")
        #expect(IngredientNormalizer.normalize("") == "")
        #expect(IngredientNormalizer.normalize("Crème Fraîche") == "creme fraiche")
    }

    @Test("Infers categories")
    func categories() {
        #expect(IngredientCategorizer.infer(from: "yellow onion") == .produce)
        #expect(IngredientCategorizer.infer(from: "chicken thigh") == .meat)
        #expect(IngredientCategorizer.infer(from: "parmesan") == .dairy)
        #expect(IngredientCategorizer.infer(from: "mystery goo") == .other)
    }
}
