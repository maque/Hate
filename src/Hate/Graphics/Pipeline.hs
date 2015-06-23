{-# LANGUAGE TypeFamilies #-}

class Pipelineish p where
    data Blueprint p :: *
    data ActivationParams p :: *

    create :: Blueprint p -> IO p
    activate :: p -> Params p -> IO ()
    
data DoublePrinter = DoublePrinter { reps :: Int }

instance Pipelineish DoublePrinter where
    data Blueprint DoublePrinter = Blueprint Int
    data ActivationParams DoublePrinter = Params ()
    create (Blueprint r) = return $ DoublePrinter { reps = r }
    activate _ _ = return ()

main :: IO ()
main = do
    p <- create (Blueprint 5)
    activate p (Params ())
    return ()
    