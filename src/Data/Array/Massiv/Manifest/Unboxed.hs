{-# LANGUAGE BangPatterns          #-}
{-# LANGUAGE FlexibleContexts      #-}
{-# LANGUAGE FlexibleInstances     #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE TypeFamilies          #-}
{-# LANGUAGE UndecidableInstances  #-}
-- |
-- Module      : Data.Array.Massiv.Manifest.Unboxed
-- Copyright   : (c) Alexey Kuleshevich 2017
-- License     : BSD3
-- Maintainer  : Alexey Kuleshevich <lehins@yandex.ru>
-- Stability   : experimental
-- Portability : non-portable
--
module Data.Array.Massiv.Manifest.Unboxed
  ( U (..)
  , VU.Unbox
  , generateM
  , fromVectorUnboxed
  , toVectorUnboxed
  , fromListsUnboxed
  , computeUnboxedS
  , computeUnboxedP
  , unsafeComputeUnboxedP
  , mapM
  , imapM
  ) where

import           Data.Array.Massiv.Common
import           Data.Array.Massiv.Compute
import           Data.Array.Massiv.Manifest
import           Data.Maybe                  (listToMaybe)
import qualified Data.Vector.Unboxed         as VU
import qualified Data.Vector.Unboxed.Mutable as MVU
import           Prelude                     hiding (mapM)
import           System.IO.Unsafe            (unsafePerformIO)

data U = U

data instance Array U ix e = UArray { uSize :: !ix
                                    , uData :: !(VU.Vector e)
                                    } deriving Eq

instance Index ix => Massiv U ix where
  size = uSize
  {-# INLINE size #-}


instance (Index ix, VU.Unbox e) => Source U ix e where
  unsafeLinearIndex (UArray _ v) = VU.unsafeIndex v
  {-# INLINE unsafeLinearIndex #-}


instance (Index ix, VU.Unbox e) => Manifest U ix e


instance (Manifest U ix e, VU.Unbox e) => Mutable U ix e where
  data MArray s U ix e = MUArray ix (VU.MVector s e)

  unsafeThaw (UArray sz v) = MUArray sz <$> VU.unsafeThaw v
  {-# INLINE unsafeThaw #-}

  unsafeFreeze (MUArray sz v) = UArray sz <$> VU.unsafeFreeze v
  {-# INLINE unsafeFreeze #-}

  unsafeNew sz = MUArray sz <$> MVU.unsafeNew (totalElem sz)
  {-# INLINE unsafeNew #-}

  unsafeLinearRead (MUArray _sz v) i = MVU.unsafeRead v i
  {-# INLINE unsafeLinearRead #-}

  unsafeLinearWrite (MUArray _sz v) i = MVU.unsafeWrite v i
  {-# INLINE unsafeLinearWrite #-}



fromListsUnboxed :: VU.Unbox e => [[e]] -> Array M DIM2 e
fromListsUnboxed !ls =
  if all (== n) (map length ls)
    then MArray (m, n) $ VU.unsafeIndex (VU.fromList $ concat ls)
    else error "fromListsVG:Inner lists are of different lengths."
  where -- TODO: check dims
    (m, n) = (length ls, maybe 0 length $ listToMaybe ls)
{-# INLINE fromListsUnboxed #-}


computeUnboxedS :: (Load r' ix, Mutable U ix e) => Array r' ix e -> Array U ix e
computeUnboxedS = computeSeq
{-# INLINE computeUnboxedS #-}


computeUnboxedP :: (Load r' ix, Mutable U ix e) => Array r' ix e -> IO (Array U ix e)
computeUnboxedP = computePar
{-# INLINE computeUnboxedP #-}


unsafeComputeUnboxedP :: (Load r' ix, Mutable U ix e) => Array r' ix e -> Array U ix e
unsafeComputeUnboxedP = unsafePerformIO . computePar
{-# INLINE unsafeComputeUnboxedP #-}


fromVectorUnboxed :: Index ix => ix -> VU.Vector e -> Array U ix e
fromVectorUnboxed sz v = UArray { uSize = sz, uData = v }
{-# INLINE fromVectorUnboxed #-}


toVectorUnboxed :: Array U ix e -> VU.Vector e
toVectorUnboxed = uData
{-# INLINE toVectorUnboxed #-}


generateM :: (Index ix, VU.Unbox a, Monad m) =>
  ix -> (ix -> m a) -> m (Array U ix a)
generateM sz f =
  UArray sz <$> VU.generateM (totalElem sz) (f . fromLinearIndex sz)
{-# INLINE generateM #-}


mapM :: (VU.Unbox b, Source r ix a, Monad m) =>
  (a -> m b) -> Array r ix a -> m (Array U ix b)
mapM f arr = do
  let !sz = size arr
  v <- VU.generateM (totalElem sz) (f . unsafeLinearIndex arr)
  return $ UArray sz v
{-# INLINE mapM #-}

imapM :: (VU.Unbox b, Source r ix a, Monad m) =>
  (ix -> a -> m b) -> Array r ix a -> m (Array U ix b)
imapM f arr = do
  let !sz = size arr
  v <- VU.generateM (totalElem sz) $ \ !i ->
         let !ix = fromLinearIndex sz i
         in f ix (unsafeIndex arr ix)
  return $ UArray sz v
{-# INLINE imapM #-}
