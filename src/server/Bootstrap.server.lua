local bootstrapFolder = script.Parent:WaitForChild("bootstrap")
local CompositionRoot = require(bootstrapFolder:WaitForChild("CompositionRoot"))

CompositionRoot.start()
