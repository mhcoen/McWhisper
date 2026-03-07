import Testing
@testable import McWhisper

@Suite("ModelCatalog")
struct ModelCatalogTests {

    @Test("Bundled model ID matches AppSettings default")
    func bundledModelIDMatchesDefault() {
        #expect(ModelCatalog.bundledModelID == AppSettings.defaultModelID)
        #expect(ModelCatalog.bundledModelID == "openai_whisper-base")
    }

    @Test("Exactly one model is marked as bundled")
    func exactlyOneBundled() {
        let bundledModels = ModelCatalog.availableModels.filter(\.isBundled)
        #expect(bundledModels.count == 1)
        #expect(bundledModels[0].id == ModelCatalog.bundledModelID)
    }

    @Test("Bundled model convenience property returns correct model")
    func bundledModelProperty() {
        let model = ModelCatalog.bundledModel
        #expect(model.id == "openai_whisper-base")
        #expect(model.isBundled == true)
        #expect(model.displayName == "Base")
    }

    @Test("Downloadable models exclude the bundled model")
    func downloadableModelsExcludeBundled() {
        let downloadable = ModelCatalog.downloadableModels
        #expect(downloadable.allSatisfy { !$0.isBundled })
        #expect(downloadable.count == ModelCatalog.availableModels.count - 1)
    }

    @Test("All model IDs are unique")
    func uniqueIDs() {
        let ids = ModelCatalog.availableModels.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Lookup by ID returns matching model")
    func lookupByID() {
        let model = ModelCatalog.model(for: "openai_whisper-small")
        #expect(model != nil)
        #expect(model?.displayName == "Small")
    }

    @Test("Lookup by unknown ID returns nil")
    func lookupUnknownID() {
        #expect(ModelCatalog.model(for: "nonexistent") == nil)
    }

    @Test("Every model has a non-empty display name and size label")
    func modelsHaveMetadata() {
        for model in ModelCatalog.availableModels {
            #expect(!model.displayName.isEmpty)
            #expect(!model.sizeLabel.isEmpty)
        }
    }

    @Test("ModelInfo equatable conformance")
    func modelInfoEquatable() {
        let a = ModelInfo(id: "x", displayName: "X", sizeLabel: "1 MB", isBundled: false)
        let b = ModelInfo(id: "x", displayName: "X", sizeLabel: "1 MB", isBundled: false)
        let c = ModelInfo(id: "y", displayName: "Y", sizeLabel: "2 MB", isBundled: true)
        #expect(a == b)
        #expect(a != c)
    }
}
