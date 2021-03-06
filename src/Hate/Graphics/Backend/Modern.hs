{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE FlexibleContexts #-}

module Hate.Graphics.Backend.Modern (BackendModern(), initialGraphicsState) where

import Hate.Graphics.Backend.Modern.Types

import Hate.Math
import Hate.Graphics.Backend.Modern.Shaders
import Hate.Graphics.Rendering
import Hate.Graphics.Pipeline.Util
import Hate.Graphics.Pipeline
import Hate.Graphics.Types
import Hate.Graphics.Backend.Util

import Control.Monad.State

import qualified Graphics.Rendering.OpenGL as GL
import Graphics.Rendering.OpenGL (($=))
import qualified Graphics.GLUtil as U

import Data.Vect.Float.OpenGL (orthoMatrix)
import Data.List (groupBy)
import Data.Maybe
import Control.Applicative

instance Renderer BackendModern where
    --initialRendererState = initialGraphicsState
    render = renderBatch
    contextRequirements _ = DesktopContext 4 4
    updateScreenSize = updateScreenSz

type Action a = (MonadState BackendModern m, MonadIO m) => m a

initialGraphicsState :: (Int, Int) -> IO BackendModern
initialGraphicsState screenSz =
    BackendModern <$> createPipeline solidColorPipelineDescs
                  <*> createPipeline texturingPipelineDescs
                  <*> createVertexStream
                  <*> pure screenSz

renderBatch :: [DrawRequest] -> Action ()
renderBatch ds = mapM_ (\xs -> renderPipelineBatch (pipeline . head $ xs) xs) $ groupBy equalPipeline ds
    where
        a `equalPipeline` b = pipeline a == pipeline b

renderPipelineBatch :: PipelineDescription -> [DrawRequest] -> Action ()
renderPipelineBatch p ds = do
    pip <- case p of
        SolidColorPipeline _ -> gets solidColorPipeline -- todo set up a proper solid color
        TexturingPipeline texId -> do
            pip <- gets texturingPipeline 
            liftIO $ activatePipeline pip
            liftIO $ GL.textureBinding GL.Texture2D $= Just texId
            return pip

    forM_ ds $ \d -> do
        let mat = transformation d .*. origin d
        setScreenTransformationUniform mat pip

        fromVertArrayIntoGlobal (vertices d, texCoords d)
        let primitiveMode = vertexLayoutToGLLayout $ vertexLayout d
        renderGlobalVertexStream primitiveMode

setScreenTransformationUniform :: Mat4 -> Pipeline -> Action ()
setScreenTransformationUniform t pip = do
    (screenSizeX, screenSizeY) <- gets screenSize

    let orthoScreenMat = orthoMatrix (0, (fromIntegral screenSizeX)) ((fromIntegral screenSizeY), 0) (-10, 10)
    let drawMat = (transpose orthoScreenMat) .*. t
    liftIO $ setUniformM4 pip "screen_transformation" drawMat

renderGlobalVertexStream :: GL.PrimitiveMode -> Action ()
renderGlobalVertexStream primitiveMode = do
    vs <- gets globalVertexStream
    liftIO $ do
        GL.bindVertexArrayObject $= Just (vao vs)
        GL.drawArrays primitiveMode 0 (fromIntegral $ vertNum vs)


updateScreenSz :: (Int, Int) -> Action ()
updateScreenSz sz = modify $ \g -> g { screenSize = sz }

fromVertArrayInto :: ([Vec2], Maybe [Vec2]) -> VertexStream -> Action VertexStream
fromVertArrayInto (verts, maybeTexCoords) s = liftIO $ do
    GL.bindBuffer GL.ArrayBuffer $= Just (vbo s)
    U.replaceBuffer GL.ArrayBuffer verts

    -- fill in texture coordinates if needed
    let texCoords' = fromMaybe (calculateTexCoords verts) maybeTexCoords
    GL.bindBuffer GL.ArrayBuffer $= Just (texVbo s)
    U.replaceBuffer GL.ArrayBuffer texCoords'
    
    return $ s { vertNum = length verts }

fromVertArrayIntoGlobal :: ([Vec2], Maybe [Vec2]) -> Action ()
fromVertArrayIntoGlobal xs = do
    m <- gets globalVertexStream
    m' <- fromVertArrayInto xs m
    modify $ \x -> x { globalVertexStream = m' }
