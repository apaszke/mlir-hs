-- Copyright 2021 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

module MLIR.BuilderSpec where

import Test.Hspec

import Control.Monad.Identity

import MLIR.AST
import MLIR.AST.Builder
import MLIR.AST.Serialize
import qualified MLIR.AST.Dialect.Std as Std
import qualified MLIR.Native as MLIR


verifyAndDump :: Operation -> Expectation
verifyAndDump op =
  MLIR.withContext \ctx -> do
    MLIR.registerAllDialects ctx
    nativeOp <- fromAST ctx (mempty, mempty) op
    MLIR.dump nativeOp
    MLIR.verifyOperation nativeOp >>= (`shouldBe` True)


spec :: Spec
spec = do
  describe "Builder API" $ do
    let combineFunc name ty combine =
          buildSimpleFunction name [ty] do
            x <- blockArgument ty
            y <- blockArgument ty
            z <- combine x y
            Std.return [z]

    it "Can construct a simple add function" $ do
      let m = runIdentity $ buildModule $ combineFunc "add" Float32Type Std.addf
      verifyAndDump m

    it "Can construct a module with two simple functions" $ do
      let m = runIdentity $ buildModule $ do
                combineFunc "add_fp32" Float32Type Std.addf
                combineFunc "add_fp64" Float64Type Std.addf
      verifyAndDump m

    it "Can loop blocks with MonadFix" $ do
      let f32 = Float32Type
      let i1  = IntegerType Signless 1
      let m = runIdentity $ buildModule $ do
                buildFunction "one_shot_loop" [f32] mdo
                  _entry <- buildBlock do
                    false <- Std.constant i1 $ IntegerAttr i1 0
                    Std.br header [false]
                  header <- buildBlock do
                    isDone <- blockArgument i1
                    result <- Std.constant f32 $ FloatAttr f32 1234.0
                    Std.cond_br isDone exit [result] body [result]
                  body <- buildBlock do
                    _ <- blockArgument f32
                    true <- Std.constant i1 $ IntegerAttr i1 1
                    Std.br header [true]
                  exit <- buildBlock do
                    result <- blockArgument f32
                    Std.return [result]
                  endOfRegion
      verifyAndDump m


main :: IO ()
main = hspec spec
