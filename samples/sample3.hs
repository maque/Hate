import qualified Graphics.Rendering.OpenGL as GL
import Glisha
import Glisha.Graphics
import Glisha.Graphics.Shapes

type SampleState = Pipeline

sampleLoad :: LoadFn SampleState
sampleLoad = do
    solidColorPipeline

sampleDraw :: DrawFn SampleState
sampleDraw = do
    get >>= activatePipeline
    draw $ PolygonWireframe $ Polygon [vec2 0 0, vec2 1 0, vec2 0 1]
    --line (vec2 0 0) (vec2 1 1)
    --circle Filled (vec2 0 0) 2

config :: Config
config = 
    Config
        { windowTitle = "Sample 3"
        , windowSize  = (480, 200)
        }

main :: IO ()
main = runApp config sampleLoad sampleDraw
