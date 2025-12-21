Solving a Wooden Puzzle Using Haskell
======================================

I got gifted a puzzle recently, allegedly a "very hard one". After receiving it,
I spent a couple minutes trying to solve it, but it quickly became clear that,
unless there was a trick I'd missed, I didn't have the right combination of
patience and brainpower for that. I had some family and friends try to solve it
too, and although some of them displayed an impressive amount of persistence,
none was persistent enough to crack the puzzle either.

You know who else is incredibly persistent? My computer. It's not nearly as smart
as the humans around me and I, but it makes up for that in speed and tirelessness.
So if I manage to tell it exactly what to do, it might be able to find a solution.
Let's try!

*This file is a literate Haskell file. This means you can run the code by
running `cabal run wooden_ puzzle.lhs`. You can also experiment with the values
defined in it by running `cabal repl wooden_puzzle.lhs`.*

*The following pieces of code are here to tell the Haskell toolchain how exactly
to interpret the file, and what our dependencies and imports are. I'll also
update them based on what I import in the second post.*

```haskell
{- cabal:
   build-depends:      base ^>= 4.17, linear ^>= 1.23, time ^>= 1.14
   default-language:   Haskell2010
   build-tool-depends: markdown-unlit:markdown-unlit
   ghc-options:        -pgmL markdown-unlit -Wall
-}
```

```haskell
module Main where

import Data.Time.Clock (getCurrentTime, diffUTCTime)
import Linear.Matrix (M33, identity, transpose, det33, (!*!), (!*))
import Linear.V3 (V3(V3))
```

## The Puzzle

Here's what the puzzle looks like:

<img src="/images/puzzle.jpg" alt="A wooden box, with a bunch of wooden pieces scattered inside it and next to it" width="320"/> 

Its principle is fairly simple: it's composed of 25 identical wooden
pieces, and a 5x5x5 cubic box. To solve the puzzle, one needs to pack the pieces
into a 5x5x5 cube, without holes nor chunks dangling out, so that it fits into
the box.

Here's what a single piece looks like: it's a 4x1x1 trunk, with a 1x1x1 cubic
notch poking out from one side:

<img src="/images/puzzle_piece.svg" alt="Simple rendering of a piece composed of a few cubes put together" width="320"/> 

The puzzle is easy enough to understand, and the fact that it's basically all
composed of cubes hints at the discrete nature of the problem, suggesting that
it would lend itself well to an algorithm search. Exactly how to model the
situation may not be completely obvious, though. We'll start setting the scene
by modeling space itself, then we'll talk about individual pieces, first in
isolation, then in the context of the whole puzzle. Along the way, we will need
a bit of math; I'll do my best to explain theoretical notions as we encounter them.

## First Steps Modeling our Problem

Since we're dealing with things that all ultimately decompose into 1x1x1 cubes,
we can think of space as a grid of voxels (the 3D equivalent to a pixel) with
integer coordinates. Mathematically, a position in that space is a vector with
three integer coordinates[^1].

The `linear` library provides the `V3` type constructor for vectors of three
coordinates; the type of positions will thus be `V3 Int`.

Since the box has dimensions 5x5x5 voxels, we'll say it contains all voxels whose
coordinates are of the form `V3 x y z`, where `x`, `y` and `z` range from 1 to 5.

Since all pieces are identical, we can get away with modeling just one "generic
piece", with arbitrary position and orientation. Every other piece can then be
recovered simply by moving this "blueprint" around. We'll pick the disposition
such that the piece's trunk extends from coordinates (0, 0, 0) to (0, 0, 3), and
its notch is located at (0, 1, 2). We model that generic piece by simply
providing the list of coordinates of the voxels that compose it:

```haskell
genericPiece :: [V3 Int]
genericPiece = [ V3 0 0 0, V3 0 0 1, V3 0 0 2, V3 0 0 3, V3 0 1 2 ]
```

Now let's tackle the hard part: describing the ways a piece can be arranged
inside the box.

Mathematically, the ways that an object may be moved around in space can be
described by specifying a rotation around the origin, and a translation.
A 3D rotation around the origin can be encoded by a 3x3 matrix, and a
translation, by a 3-component vector:

```haskell
data Disposition = Disposition
  { rotation    :: M33 Int
  , translation :: V3 Int
  } deriving Show
```

Now, for a given disposition of a piece, we need a way to get the coordinates
of the cubes that compose the piece. To do that, we just apply the rotation and
the translation to each cube of the generic piece.

```haskell
dispositionCoordinates :: Disposition -> [V3 Int]
dispositionCoordinates disposition = fmap applyTransform genericPiece
  where
  -- Note that we are applying the translation after the rotation. We could
  -- technically apply the the translation first, but I think it makes
  -- more intuitive sense to first choose our piece's orientation and then
  -- translate it. In the end, what matters is that we stick to our convention.
  applyTransform :: V3 Int -> V3 Int
  applyTransform vector =
    translation disposition + (rotation disposition !* vector)
```

## Our Action Plan to Enumerate All Dispositions

The `Disposition` datatype is able to represent any possible disposition of a
piece in the box. What we'll need to solve the puzzle is to enumerate all
those dispositions, but if we try to do so, we'll run into two problems:

1. Not all values of type `Disposition` actually correspond to a valid disposition:
   - The `rotation` field is of type `M33 Int`, but not all `M33 Int` matrices
     correspond to rotations: some of them encode transforms that mirrors their
     input, others, to transforms that inflate it, and others do weirder stuff yet.
   - Even in cases where the `rotation` field actually encodes a rotation, the
     specific disposition encoded by a given `Disposition` might not fit in the
     box.
2. The `Disposition` datatype is infinite (ignoring technicalities): it has fields
   of type `V3 Int` and `M33 Int`, which both have `Int` coefficients, and `Int`
   is infinite. So even if we wanted to list all possible `Disposition`s, we couldn't.

Fortunately, it turns out that there are only finitely many possible dispositions,
so there's still hope that we might be able to list them all. Directly enumerating
them would be too difficult, though, so we will decompose the task:

1. First, we'll make up a list of *candidate dispositions*. This list will have two
   important properties:
   - Any *valid* disposition will appear in the list, even though the list might
     still (and will) feature invalid ones.
   - The list will be finite, so we'll be able to enumerate it.
2. Then we'll define a predicate on dispositions, that is, a function of type
   `Disposition -> Bool`, which will tell us — this time with certainty —
   whether a given disposition is valid.

To get the full, exclusive list of valid dispositions, we'll then just need to
filter out invalid dispositions from the list of candidate ones.

<img src="/images/puzzle_venn.svg" alt="Simple rendering of a piece composed of a few cubes put together" width="320"/> 

## Enumerating Candidate Dispositions

A `Disposition` has two fields; let's look at each of those in detail. First,
the `rotation` field. `rotation`s are encoded by a value of type `M33 Int`.
As we saw earlier, though, not all values of that type encode a rotation. Is
there a simple way to narrow `M33 Int` down to an easily enumerated collection?
There is!

To do that, we first need to talk a bit about what the coefficients of a 3x3
matrix represent. Say you have a 3D linear transform, and you want to write down
the matrix *M* that corresponds to it (in the standard coordinate system with axes
X, Y and Z). The first thing you do is apply the transform to the X axis. You
end up with a vector that is no longer necessarily aligned with the X axis;
instead, it has components along the X, Y and Z axis. The coefficients on the
first row of the *M* correspond to how much of each of the three axes appear in
our transformed X axis. Then the second row correspond to the same, but starting
with the Y axis, and the third row, to the Z axis.

That's for a general linear transform. But we're dealing with the much more
specific case of rotations in a voxel world. If you think a bit about what happens
in you rotate one of the three axes when you rotate it in that context, you'll
find that it either:

- Remains unchanged.
- Gets flipped.
- Turns into another axis.
- Turns into the flipped version of another axis.

In all four cases, the corresponding matrix row will contain a 1 or a -1
coefficient for the resulting axis, and a 0 coefficient elsewhere. This means
that if we enumerate all possible matrices with coefficients -1, 0 and 1, we'll
get all valid rotation matrices! We do so using Haskell's handy syntactic sugar
for [list comprehension](https://wiki.haskell.org/List_comprehension):

```haskell
candidateRotations :: [M33 Int]
candidateRotations = [
  -- The `M33` type is actually just two nested `V3` in a trench coat:
  V3 (V3 m11 m12 m13)
     (V3 m21 m22 m23)
     (V3 m31 m32 m33)
  | m11 <- [-1..1], m12 <- [-1..1], m13 <- [-1..1]
  , m21 <- [-1..1], m22 <- [-1..1], m23 <- [-1..1]
  , m31 <- [-1..1], m32 <- [-1..1], m33 <- [-1..1]
  ]
```

Again, keep in mind that this list contains many matrices that do *not*
correspond to valid rotations. But all valid rotations do appear in it.

Now we'll need to narrow the possible translations down into a finite list too.
The following paragraph is my attempt at explaining somewhat rigorously how we
do that; it's a little convoluted, but the general idea is fairly intuitive:
we care only about dispositions that fit in the box, so we can rule out any
disposition that translates the `genericPiece` too far away.

Ok, now here's the "rigorous" explanation: the `V3 Int` type is able to encode
arbitrarily long translations, but we're only interested in those that keep
the piece in our 5x5x5 box. Taking a look at the `genericPiece` above, remark
that it contains the cube at the origin, `V3 0 0 0`. Regardless of the rotation
matrix we apply, it will leave that cube unchanged. This means that only
the `translation` field impacts the origin cube. In other words, in any piece
given by a value of type `Disposition`, the coordinates of the cube
corresponding to the `genericPiece`'s cube at the origin are exactly the
`translation`'s field coordinates. Since we want all the cubes in our piece to
fit in the box, all coefficients must be between 1 and 5. So we can rule out
any disposition whose `translation` field features coefficients outside that
range, and we can finitely enumerate a list of candidate translations:

```haskell
candidateTranslations :: [V3 Int]
candidateTranslations = [ V3 x y z | x <- [1..5], y <- [1..5], z <- [1..5] ]
```

Now that we have an enumeration of candidates for each of `Disposition`'s fields,
we can put them together to get a list of candidate `Disposition`s:

```haskell
candidateDispositions :: [Disposition]
candidateDispositions =
  [ Disposition rot trans | rot   <- candidateRotations
                          , trans <- candidateTranslations ]
```

## Filtering Out Remaining Invalid Dispositions

Now on to filtering out the remaining invalid dispositions! First we'll weed out
invalid rotations. We don't need to get into the details here, but it turns out
there's an easy way to tell whether a given 3x3 matrix encodes a rotation: a 3x3
matrix *M* encodes a rotation exactly when it is part both of the
[orthogonal linear group](https://en.wikipedia.org/wiki/Orthogonal_group) and the
[special linear group](https://en.wikipedia.org/wiki/Special_linear_group).
In more concrete terms, this means *M* fulfils the following two conditions:

1. *M* multiplied by its transpose is the identity matrix.
2. *M*'s determinant is 1.

In Haskell, this translates to:

```haskell
-- | Does the given matrix encode a rotation?
isRotation :: M33 Int -> Bool
isRotation matrix = ((transpose matrix !*! matrix) == identity) &&
                    (det33 matrix == 1)
```

We're almost done describing all possible dispositions! We know what a valid
rotation looks like, now the one problem we might still have is a piece arranged
in such a way that it doesn't fit in the box. That's easy, we just need to check
that each cube of the piece fits in the box:

```haskell
pieceFitsTheBox :: Disposition -> Bool
pieceFitsTheBox disposition =
  all cubeFitsTheBox (dispositionCoordinates disposition)
  where cubeFitsTheBox :: V3 Int -> Bool
        cubeFitsTheBox (V3 x y z) = x >= 1 && x <= 5 &&
                                    y >= 1 && y <= 5 &&
                                    z >= 1 && z <= 5
```

And a valid disposition is one whose `rotation` field is actually a rotation,
and which results in a piece that fits in the box:

```haskell
isValidDisposition :: Disposition -> Bool
isValidDisposition disposition = isRotation (rotation disposition) &&
                                 pieceFitsTheBox disposition
```

Putting it all together, we get a list of all valid dispositions by starting from
the list of candidate dispositions and filtering out invalid ones:

```haskell
allValidDispositions :: [Disposition]
allValidDispositions = filter isValidDisposition candidateDispositions
```

We're pretty much done for this first blog post, but I'd like to prepare for the
next one with one last step: our `Disposition` datatype served us well, but all
we will need now to solve the puzzle is the actual coordinates of the cubes that
compose the pieces. So we'll convert it all to coordinates:

```haskell
allValidPieces :: [[V3 Int]]
allValidPieces = fmap dispositionCoordinates allValidDispositions
```

Phew! That was a little tedious, but now everything's in place for next part,
where we'll leverage Haskell's conciseness to actually solve the puzzle in a very
elegant way. See you then!

...

Last time we defined a list `allValidPieces` of all the ways that a piece may
be fitted in the box. Its type is the nested list `[[V3 Int]]`, because we
represent a single piece as a list of the voxels that compose it. Looks like
we're going to deal with lots of nested lists... Let's try to prevent confusion
by defining a type synonym:

```haskell
type Shape = [V3 Int]
```

`Shape` will typically represent a puzzle piece, but it can represent any chunk
of voxels. We'll use it below to represent a set of pieces lumped together.

## Compatibility Matters

Ok, moving on. Let's recall what we are after: we need to find a way to fit 25
pieces in the box simultaneously. In other words, we're looking for a
subcollection of `allValidPieces` that has 25 elements, such that no two
elements interpenetrate one another. Which begs the question: what does it mean,
formally, for two shapes to interpenetrate one another?

Recall that we represented a piece as the list of voxels that compose it. Two
shapes, then, are in conflict when they have at least one voxel in common — in
other words, when there is any voxel from the first that is also an element of
the second:

```haskell
conflict :: Shape -> Shape -> Bool
conflict shape1 shape2 = any (\voxel -> elem voxel shape2) shape1
```

At this point, I'd say we're finally done modeling the problem and can start
looking for a solution!

25 pieces is a lot, we can't just repeatedly pick lists of 25 pieces until we
come across one where pieces happen to not conflict with one another. We need to
build our solution step by step, and for that, we need a way to find out what
pieces are compatible with a collection of pieces already in place. Out of
performance concerns, we won't encode the collection of pieces already in place
using a list of `Shape`s, but we'll lump them all together in one single
`Shape` composed of the voxels that are already occupied by some piece:

```haskell
newCompatiblePieces :: Shape   -- ^ Voxels to avoid
                    -> [Shape] -- ^ All pieces that do not conflict with the input shape
newCompatiblePieces occupiedVoxels =
  filter
    (\candidatePiece -> not $ conflict candidatePiece occupiedVoxels)
    allValidPieces
```

Note that in the above function, we are looking for all pieces that do not
conflict with the input, but the pieces in the output list will generally
conflict with one another. That's not a problem: the output list should not be
seen as a list of pieces to add, but as a list of *options* which we can choose
from.

Of course, some of the potentially compatible pieces we find, while they do not
directly conflict with any piece already in place, will lead to a dead-end
nevertheless: there is no solution compatible with both the pieces in place and
the new piece. That's actually kind of the point of our puzzle!: we can't solve
it just by adding piece after piece as long as they fit.

With an imperative apprach, we'd deal with this problem using explicit
[backtracking](https://en.wikipedia.org/wiki/Backtracking), keeping track, at
each step, of the pieces we've tried, and going back one step whenever we don't
find what we're looking for. This is hard to think about! In Haskell, we
have a cheat code, and that's called:

## Parallel Universes with the `List` Monad

I like to think of monads and `do` notation as a way for the programmer to pretend
they have access to a pure value when they don't actually. In the `IO` monad,
writing `userInput <- getLine` is a way to pretend you have a value of type
`String`, even though you need to wait for `getLine` to be executed at runtime
for the value to actually be defined. In the `Maybe` monad, writing
`result <- someComputation` is a way to pretend that `someComputation` yielded
a normal value, which you can access under the name `result`, even though
`someComputation` might be `Nothing` — in which case the whole `do` block becomes
`Nothing`.

Enter the `List` monad (also known as the `[]` monad, but that's harder to
pronounce). If `someList` is a list of type `[a]`, you can write
`value <- someList` and proceed as though `value` were an actual value of type
`a`, even though there may be zero or more than one elements in the list.
What mechanism makes that possible? When you write `value1 <- someList1`, the
universe *splits into several parallel subuniverses*, and everything you write
under that line in the do block is computed/executed as many times as there are
elements in `someList1`. If you write `value2 <- someList2` below that, *each
of those parallel universes splits into parallel universes again*, one for each
element of `someList2`. If you're not careful, the number of branches can explode
quickly!

With that in mind, we can implement our function that recursively looks for
*subsolutions* of the puzzle: lists of *n* compatible pieces (for some input *n*
between 0 and 25) that do not conflict with a collection of pieces (again,
lumped together into a single `Shape`) assumed to already be in place:

```haskell
subsolutions :: Int   -- ^ How many pieces should be in the subsolution we're looking for?
             -> Shape -- ^ Unavailable voxels, already occupied by some piece
             -> [[Shape]] -- ^ List of subsolutions, each of which is itself a list of pieces
subsolutions 0 _ = [[]]
subsolutions n occupiedVoxels = do
  newPiece <- filter
                (\piece -> not (conflict occupiedVoxels piece))
                allValidPieces
  let updatedOccupiedVoxels = newPiece <> occupiedVoxels
  otherPieces <- subsolutions (n - 1) updatedOccupiedVoxels
  return $ newPiece : otherPieces
```

The base case is *n* = 0: there is exactly one solution with zero pieces, that's
the list with no piece in it. Now look at what happens in the other branch:
- We look for candidate pieces (on the right of the first `<-`), that is, pieces
  that do not conflict with our list of occupied voxels;
- Using the magical `<-` symbol, we split the universe into as many parallel
  universes as there are candidate pieces; in each subuniverse, `newPiece`
  will be defined to be the corresponding candidate piece;
- In each parallel universe, we perform a recursive call, looking for the list
  of subsolutions that are compatible with both the original list of occupied
  voxels and our new piece;
- Again, we split each universe into many parallel subuniverses, one for each
  of those subsolutions;
- For each universe, we return the resulting subsolution. The actual result is
  a list with one value for each universe.

Now you might think "gosh, that's *a lot* of universes to split into, how is my
computer ever going to deal with those?", and you'd be right. There are two
reasons for hope, though:
- Some combinations of pieces will not allow for any new piece to be fit into
  the box. In that case, the corresponding list of subsolutions will be empty,
  which means that instead of splitting the corresponding universe into
  subuniverses, the whole branch will die off. In other words, sometimes the
  total number of universes will decrease.
- Non-strict evaluation! This is all implemented with Haskell's lazy list type.
  This means that as long as you're not trying to print the whole list of
  solutions, not all parallel universes will actually be explored. Typically,
  you'll want to print only the first element of the list of solutions, in
  which case your program will stop as soon as it's found one.

Anyway, the final list of solutions (there may be more than one!) to our problem
is then:

```haskell
allSolutions :: [[Shape]]
allSolutions = subsolutions 25 []
```

and we get an arbitrary solution by taking the first element of the list with
`head`.

Alas, my computer hangs and never returns a value. It seems that we were too
careless splitting the universe many times, and the computer can't handle the
resulting combinatorial explosion. Honestly, this isn't too surprising. Our
approach is as bruteforce as it gets — which is actually good for a first
approach: as Donald Knuth puts it,
["premature optimization is the root of all evil (or at least most of it) in programming"](https://en.wikiquote.org/wiki/Donald_Knuth).

Ok, but what now? I guess we'll need to dig into optimization literature, or
maybe turn the problem into a SAT formula and fire up a SAT solver... Just
kidding! We're still going to bruteforce our problem, we just need to be smarter
about it.

## A Slightly Smarter Solution

We don't need to look far, in the way we built our final list of solutions, to
find sources of redundancy — (sub)solutions that are equivalent to one another,
but are nevertheless registered separately. For two given compatible piece
dispositions `piece1` and `piece2`, for instance, `[piece1, piece2]` and
`[piece2, piece1]` count as two subsolutions, even though they obviously
represent the same situation. The search will be performed once for each, and
if it leads nowhere, well... too bad, you will have wasted twice as much time.
And this will be true for any combination of compatible pieces, at any recursive
call. No wonder the algorithm is inefficient!

So, how are we to reduce the search space? Well, assume that you have a
subsolution and you're looking for a piece to add to it in order to get closer
to the full solution. Now take any free voxel `freeVoxel`, that is, any voxel
that is not part of any of the subsolution's pieces. Since we ultimately want
to fill the 5x5x5 cube, we know for sure that the full solution will feature a
piece that contains `freeVoxel`. So we can restrict our search to only pieces
that do!

Let's first implement a function that picks any free voxel in the box. We just
define a list composed of all of the box's voxels, filter out those that are
contained in one of the pieces in place, and take the first element of the
filtered list using `head`:

```haskell
pickFreeVoxel :: Shape -> V3 Int
pickFreeVoxel alreadyOccupiedVoxels =
  head $
  filter (\voxel -> not $ elem voxel alreadyOccupiedVoxels) $
  [V3 x y z | x <- [1..5], y <- [1..5], z <- [1..5]]
```

It isn't hard, now, to modify our `subsolutions` function so that it implements
our "smarter" bruteforce algorithm:

```haskell
subsolutionsSmart :: Int   -- ^ How many pieces should be in the subsolution we're looking for?
                  -> Shape -- ^ Unavailable voxels, already occupied by some piece
                  -> [[Shape]]
subsolutionsSmart 0 _ = [[]]
subsolutionsSmart n occupiedVoxels = do
  let freeVoxel = pickFreeVoxel occupiedVoxels
  newPiece <- filter
                  (\piece -> elem freeVoxel piece &&
                             not (conflict occupiedVoxels piece)
                  )
                  allValidPieces
  let updatedOccupiedVoxels = newPiece <> occupiedVoxels
  otherPieces <- subsolutionsSmart (n - 1) updatedOccupiedVoxels
  return $ newPiece : otherPieces
```

The only change is that each time we're looking for a new piece, we pick a
`freeVoxel` and filter out pieces that don't contain it. Note that while
`newPiece` is on the left of a left arrow `<-`, because we want to be
considering *all* pieces in the list, `freeVoxel` is defined using a normal
`let` assignment. That's because, even though *any* free voxel will do, we only
want to consider one.

And finally, to get the full list of solutions, we do exactly the same as above:

```haskell
allSolutionsSmart :: [[Shape]]
allSolutionsSmart = subsolutionsSmart 25 []
```
We only want one solution, so we print the first element (or `head`) of that
list, and we measure the time it takes:

```haskell
main :: IO ()
main = do
  startTime <- getCurrentTime
  print $ head allSolutionsSmart
  endTime <- getCurrentTime
  putStrLn $ "Found in " <>
             show (realToFrac (diffUTCTime endTime startTime) :: Double) <>
             " seconds."
```

And my computer does find a solution, in a little more than 30 minutes!

## Conclusion

I don't have a moral to this story, it was just a fun case study. But here are
three suggestions of ways the program could be improved.

- Optimization. On the one hand, the fact that a bruteforcing approach was able
  to find us a solution at all is pretty nice. On the other hand, 30 minutes is
  still quite a long time! The algorithm could probably be optimized, for instance
  by favoring subsolutions that are more "compact", for some definition of "compact"...

- If you run the program at home, the output you'll get is a frankly illegible
  list of lists of vector values that look like `V3 2 4 1`. I was able to test my
  solution in practice by manually drawing the corresponding pieces, and then packing the pieces
  according to my drawing, but I won't lie, the process was pretty tedious. So
  another possible improvement could be to find a way to pretty-print the solution(s)
  the algorithm finds. It's not obvious how to do so, especially with text output!

- Finally, you might want to get all possible solutions, and for that,
  to get rid of solutions that are rotated and/or mirrored versions of other
  solutions. Better yet, you could try to avoid generating them in the first
  place (in the same   way that we found a trick to avoid generating solutions
  that were the same up to a rearrangement of the piece order).

Feel free to tell me if you make progress on either front!

[^1]: *Pedantic note: Mathematically speaking, a vector cannot have integer
      coordinates. The coordinates of a vector must take values in a field,
      and integers do not form a field, only a ring. The technical term for
      "vector space"-like objects over something that's only a ring is
      [module](https://en.wikipedia.org/wiki/Module_\(mathematics\)).
      Of course this lexical matter has absolutely no consequence on the rest,
      so we'll keep talking about "vectors".*
