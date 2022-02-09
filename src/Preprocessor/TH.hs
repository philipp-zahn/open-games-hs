{-# LANGUAGE TemplateHaskell #-}
{-# LANGUAGE NamedFieldPuns #-}

module Preprocessor.TH (Variables(..)
                       , Expressions(..)
                       , FreeOpenGame(..)
                       , FunctionExpression(..)
                       , interpretOpenGame
                       , interpretFunction
                       , mkTup
                       ) where

import Language.Haskell.TH
import Language.Haskell.TH.Syntax
import Preprocessor.Types

mkTup :: [Exp] -> Exp
mkTup [x] = x
mkTup x = TupE $ map Just x

combinePats :: [Pat] -> Pat
combinePats [x] = x
combinePats xs = TupP xs

apply :: Exp -> [Exp] -> Exp
apply fn [] = fn
apply fn (x : xs) = apply (AppE fn x) xs

patToExp :: Pat -> Exp
patToExp (VarP e) = VarE e
patToExp (TupP e) = mkTup (map (patToExp) e)
patToExp (LitP e) = LitE e
patToExp (ListP e) = ListE (fmap patToExp e)
patToExp (ConP n e) = apply (VarE n) (fmap patToExp e)

interpretFunction :: FunctionExpression Pat Exp-> Q Exp
interpretFunction Identity = [| id |]
interpretFunction Copy = [| \x -> (x, x) |]
-- interpretFunction (Lambda (Variables vars) (Expressions exps)) =
--   case (vars, exps) of
--     ([v], [e]) -> pure $ LamE (pure $ v) e
--     ( v , [e]) -> pure $ LamE (pure $ TupP v) e
--     ([v],  e ) -> pure $ LamE (pure $ v) (mkTup e)
--     ( v ,  e ) -> pure $ LamE (pure $ TupP v) (mkTup e)
-- interpretFunction (CopyLambda (Variables vars) (Expressions exps)) =
--   case (vars, exps) of
--     ([v], [e]) -> pure $ LamE (pure $      v) (mkTup [            patToExp v,       e])
--     ( v , [e]) -> pure $ LamE (pure $ TupP v) (mkTup [mkTup $ map patToExp v,       e])
--     ([v],  e ) -> pure $ LamE (pure $      v) (mkTup [            patToExp v, mkTup e])
--     ( v ,  e ) -> pure $ LamE (pure $ TupP v) (mkTup [mkTup $ map patToExp v, mkTup e])

interpretFunction (Lambda (Variables [vars]) (Expressions exps)) =
  pure $ LamE (pure $ vars) (mkTup exps)
interpretFunction (Lambda (Variables vars) (Expressions exps)) =
  pure $ LamE (pure $ TupP vars) (mkTup exps)
interpretFunction (CopyLambda (Variables [vars]) (Expressions exps)) =
  pure $ LamE (pure $ vars) (mkTup [mkTup $ [patToExp vars], mkTup exps])
interpretFunction (CopyLambda (Variables [vars]) (Expressions exps)) =
  pure $ LamE (pure $ vars) (mkTup [mkTup $ [patToExp vars], mkTup exps])
interpretFunction (CopyLambda (Variables vars) (Expressions exps)) =
  pure $ LamE (pure $ TupP vars) (mkTup [mkTup $ map patToExp vars, mkTup exps])

interpretFunction (Multiplex (Variables vars) (Variables vars')) =
  pure $ LamE (pure $ TupP [combinePats vars, combinePats vars']) (mkTup $ map patToExp (vars ++ vars'))
interpretFunction (Curry f) = [| curry $(interpretFunction f)|]


interpretOpenGame :: FreeOpenGame Pat Exp-> Q Exp
interpretOpenGame (Atom n) = pure n
interpretOpenGame (Lens f1 f2) = [| fromLens $(interpretFunction f1) $(interpretFunction f2) |]
interpretOpenGame (Function f1 f2) = [| fromFunctions $(interpretFunction f1) $(interpretFunction f2)|]
interpretOpenGame Counit = [| counit |]
interpretOpenGame (Sequential g1 g2) = [| $(interpretOpenGame g1) >>> $(interpretOpenGame g2)|]
interpretOpenGame (Simultaneous g1 g2) = [| $(interpretOpenGame g1) &&& $(interpretOpenGame g2)|]
