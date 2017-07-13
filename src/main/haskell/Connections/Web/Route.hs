{-# LANGUAGE OverloadedStrings #-}

module Connections.Web.Route where

import qualified Connections.Game.Play           as Play
import qualified Connections.Web.Controller      as Controller
import qualified Connections.Web.Store           as Store
import qualified Data.Aeson.Types                as Aeson
import qualified Data.Text                       as Text
import qualified System.IO                       as IO
import qualified Web.Scotty                      as Scotty

import Connections.Web.Store (Store)
import Control.Monad.IO.Class (MonadIO, liftIO)
import Data.Aeson.Types
import Data.Monoid ((<>))
import Data.Text (Text)
import Text.Read (readMaybe)

-- | Add routes for routes the browser might visit directly.
staticRoutes :: Scotty.ScottyM ()
staticRoutes = do
    -- | Load the HTML page that will download and execute the thick JS client.
    Scotty.get "/" $ do
        Scotty.file "src/main/resources/static/index.html"

    serveStaticDirectory "/static/" "src/main/resources/static/"

serveStaticDirectory :: Text -> Text -> Scotty.ScottyM ()
serveStaticDirectory staticRouteDirectory staticDirectory = do
    let routePath = Text.unpack ("^" <> staticRouteDirectory <> "(.*)$")

    Scotty.get (Scotty.regex routePath) $ do
        filePath <- Scotty.param "1"

        -- TODO: Is this vulnerable to directory traversal attacks? Doesn't seem
        -- like it from trying, but I should look into this more
        Scotty.file ((Text.unpack staticDirectory) <> filePath)

-- | Add routes for all the API calls
--
-- Each route returns JSON
--   On success: { results: { ... } }
--   On failure: { errors: ["..."] }
apiRoutes :: Controller.AppConfig -> Store IO -> Scotty.ScottyM ()
apiRoutes appConfig store = do
    let key = Store.Key ""

    -- | Ends the turn for the current team. Mutations will be visible in
    -- "/api/status". Returns `null` as a result.
    Scotty.get "/api/end_turn" $ do
        let action = Controller.Move Play.EndTurn
        let controllerResponse = Controller.onAction appConfig store key action
        apiResponse <- liftIO controllerResponse
        Scotty.json apiResponse

    -- | Given the integer values for the parameters "i" and "j", guess the
    -- 0-indexed square (i, j). Mutations will be visible in "/api/status".
    -- Returns `null` as a result.
    Scotty.get "/api/guess" $ do
        i <- Scotty.param "i"
        j <- Scotty.param "j"

        let action = Controller.Move (Play.Guess (i, j))
        let controllerResponse = Controller.onAction appConfig store key action
        apiResponse <- liftIO controllerResponse

        Scotty.json apiResponse

     -- | Generates a new game. Mutations will be visible in "/api/status".
    -- Returns `null` as a result.
    Scotty.get "/api/new_game" $ do
        let controllerResponse = Controller.onAction appConfig store key Controller.NewGame
        apiResponse <- liftIO controllerResponse
        Scotty.json apiResponse

    -- | Reads the state of the game, if there is one; otherwise, return `null`
    -- as the result.
    Scotty.get "/api/status" $ do
        let controllerResponse = Controller.onAction appConfig store key Controller.Status
        apiResponse <- liftIO controllerResponse
        Scotty.json apiResponse
