module Lexer where

import Data.Ratio
import Data.Word
import Data.Char (isLetter, isSpace, isAlphaNum, isDigit)
import Control.Monad.State
import Test.HUnit (Test(..), assertEqual, runTestTT) 

-- | The 'TokenType' describes the different kinds of tokens
data TokenType =  StartToken        -- ^ Artificial token, corresponding to a lexer state where no token has been lexed 
                | EndToken          -- ^ Artificial token, indicating that the lexer has reached the input string 
                | IdentifierToken   -- ^ Identifier, i.e. string starting with a letter and containing arbitrary alphanumeric chararacters afterwards 
                | NumberToken       -- ^ Rational number, i.e. '12' or '12.34' without sign. Things like '.5' or '12.' are not allowed 
                | PlusToken         -- ^ '+' token 
                | MinusToken        -- ^ '-' token 
                | AsteriskToken     -- ^ '*' token 
                | DivisionToken     -- ^ '/' token 
                | LeftBracketToken  -- '(' token 
                | RightBracketToken -- ')' token 
                | LeftCurlyToken    -- '{' token  
                | RightCurlyToken   -- '}' token 
                | AssignmentToken   -- '=' token 
                deriving (Show, Eq) 

-- | A 'Token' containes all information about a token, i.e. its literal value, the position in the input string and its TokenType
data Token = Token { tokenType     :: TokenType -- ^ type of the token
                     , tokenString   :: String  -- ^ string representing the token
                     , tokenPosition :: Int     -- ^ position in the input string
                   } deriving (Show, Eq)

-- | The 'LexerError' indicates a failure in the lexing process
data LexerError =   InvalidToken String     -- ^ Token is invalid, e.g. contains invalid characters 

-- | The 'LexerInternalState' contains the input string and the current position in the input string 
data LexerInternalState = LexerPosition { lexerString :: String   -- ^ Input string
                                          , lexerPosition :: Int  -- ^ Position in input string 
                                        }
-- | The 'LexerResult' is the result of an invokation of 'lookAhead' or 'getNextToken'
newtype LexerResult = LexerResult ( Either LexerError Token ) 

-- | The 'LexerState' contains the result of an invokation of 'lookAhead' or 'getNextToken', i.e. the 
--   lexer state and the obtained token.
type LexerState = State LexerInternalState LexerResult 

-- | The 'initializeLexer' function initializes the state of the Lexer
initializeLexer :: String -> LexerState
initializeLexer string = state initialState where
 initialState :: LexerInternalState -> (LexerResult, LexerInternalState)
 initialState state = (LexerResult ( Right ( Token { tokenType=StartToken, tokenString=[], tokenPosition = 0 } ) ),  
   LexerPosition { lexerString=string, lexerPosition=0 } )  

-- | The 'matchIdentifier' function matches a single identifier.
matchIdentifier :: String              -- ^ input string 
                   -> Int              -- ^ position in input string 
                   -> Maybe Token      -- ^ Nothing if no identifier matched, else the generated token 
matchIdentifier s pos | length s <= pos = Nothing 
                      | otherwise       = let start = drop pos s
                                              token = takeWhile isAlphaNum start
                                          in if ( length token > 0 ) && ( isLetter $ head token ) 
                                             then return Token { tokenType = IdentifierToken, tokenString = token, tokenPosition = pos }
                                             else Nothing

-- | The 'matchSingleChars' function matches all operators and brackets 
matchSingleChars :: String      -- ^ input string 
                 -> Int         -- ^ position in input string 
                 -> Maybe Token -- ^ 'Nothing', if no operator or bracket has been matched, else the generated token 
matchSingleChars s pos | length s <= pos = Nothing
                       | otherwise       = let start = head $ drop pos s  
                                               ret s = return Token { tokenType=s, tokenString=[start], tokenPosition=pos }  
                                           in case start of 
                                             '+' -> ret PlusToken
                                             '-' -> ret MinusToken
                                             '*' -> ret AsteriskToken
                                             '/' -> ret DivisionToken
                                             '(' -> ret LeftBracketToken
                                             ')' -> ret RightBracketToken
                                             '{' -> ret LeftCurlyToken
                                             '}' -> ret RightCurlyToken
                                             _   -> Nothing

-- | The 'checkNumberStart' function checks, if a given combination of digits forms a number
--   For example: '0012' is not a valid number, but '0.12' is
checkNumberStart :: String  -- ^ input string 
                    -> Int  -- ^ position in input string
                    -> Bool -- ^ is start of valid number
checkNumberStart s pos | length s <= pos = False 
                       | otherwise       = let start = drop pos s
                                           in case length start of 
                                              1 -> isDigit $ head start 
                                              _ -> (isDigit $ head start) && (not ( ( head start == '0') && (isDigit $ head $ tail start ))) 

-- | The 'matchNumber' function matches a single number, e.g. '12.43'
matchNumber :: String         -- ^ input string 
               -> Int         -- ^ position in input string 
               -> Maybe Token -- ^ 'Nothing' if no number has been found at the given position, else the token 
matchNumber s pos | length s <= pos        = Nothing 
                  | checkNumberStart s pos = let matchNumberDo :: String -> String 
                                                 matchNumberDo s  = let beforeDot    = takeWhile isDigit s
                                                                        rest         = drop (length beforeDot) s
                                                                        afterDot     = if length rest > 1 && head rest == '.' 
                                                                                       then ['.'] ++ takeWhile isDigit (tail rest) else []  
                                                                    in beforeDot ++ afterDot 
                                                 number = matchNumberDo (drop pos s) 
                                             in return Token { tokenType=NumberToken, tokenString=number, tokenPosition=pos } 
                 | otherwise               = Nothing


-- Unit Test section --

testMatchIdentifier1  = TestCase (assertEqual "hugo" (Just Token { tokenType=IdentifierToken, tokenString="hugo", tokenPosition=0 }) (matchIdentifier "hugo" 0))
testMatchIdentifier2  = TestCase (assertEqual "ugo" (Just Token { tokenType=IdentifierToken, tokenString="ugo", tokenPosition=1 }) (matchIdentifier "hugo" 1))
testMatchIdentifier3  = TestCase (assertEqual "go" (Just Token { tokenType=IdentifierToken, tokenString="go", tokenPosition=2 }) (matchIdentifier "hugo" 2))
testMatchIdentifier4  = TestCase (assertEqual "o" (Just Token { tokenType=IdentifierToken, tokenString="o", tokenPosition=3 }) (matchIdentifier "hugo" 3))
testMatchIdentifier5  = TestCase (assertEqual "<Nothing>" (Nothing) (matchIdentifier "hugo" 4))
testMatchIdentifier6  = TestCase (assertEqual "hello" (Just Token { tokenType=IdentifierToken, tokenString="hello", tokenPosition=0 }) (matchIdentifier "hello welt" 0))
testMatchIdentifier7  = TestCase (assertEqual "hello" (Nothing) (matchIdentifier "hello welt" 22))
testMatchIdentifier8  = TestCase (assertEqual "hello" (Nothing) (matchIdentifier "" 0))
testMatchIdentifier9  = TestCase (assertEqual "hello" (Nothing) (matchIdentifier "" 1))
testMatchIdentifier10 = TestCase (assertEqual "1hugo" (Nothing) (matchIdentifier "1hugo" 0))
testMatchIdentifier11 = TestCase (assertEqual "hugo" (Just Token { tokenType=IdentifierToken, tokenString="hugo", tokenPosition=1 }) (matchIdentifier "1hugo" 1))
testMatchIdentifier12 = TestCase (assertEqual "+hugo" (Nothing) (matchIdentifier "+hugo" 0))
testMatchIdentifier13 = TestCase (assertEqual "hugo" (Just Token { tokenType=IdentifierToken, tokenString="hugo", tokenPosition=1 }) (matchIdentifier "+hugo" 1))
testMatchIdentifier14 = TestCase (assertEqual "+" (Nothing) (matchIdentifier "+" 0))
testMatchIdentifier15 = TestCase (assertEqual "-" (Nothing) (matchIdentifier "-" 0))
testMatchIdentifier16 = TestCase (assertEqual "*" (Nothing) (matchIdentifier "*" 0))
testMatchIdentifier17 = TestCase (assertEqual "/" (Nothing) (matchIdentifier "/" 0))
testMatchIdentifier18 = TestCase (assertEqual "(" (Nothing) (matchIdentifier "(" 0))
testMatchIdentifier19 = TestCase (assertEqual ")" (Nothing) (matchIdentifier ")" 0))
testMatchIdentifier20 = TestCase (assertEqual "{" (Nothing) (matchIdentifier "{" 0))
testMatchIdentifier21 = TestCase (assertEqual "}" (Nothing) (matchIdentifier "}" 0))
testMatchIdentifier22 = TestCase (assertEqual "=" (Nothing) (matchIdentifier "=" 0))
testMatchIdentifier23 = TestCase (assertEqual "." (Nothing) (matchIdentifier "." 0))
testMatchIdentifier24 = TestCase (assertEqual "0" (Nothing) (matchIdentifier "0" 0))
testMatchIdentifier25 = TestCase (assertEqual "1" (Nothing) (matchIdentifier "1" 0))
testMatchIdentifier26 = TestCase (assertEqual "2" (Nothing) (matchIdentifier "2" 0))
testMatchIdentifier27 = TestCase (assertEqual "9" (Nothing) (matchIdentifier "9" 0))

tests = TestList [
                    TestLabel "matchIdentifier Test1"   testMatchIdentifier1,
                    TestLabel "matchIdentifier Test2"   testMatchIdentifier2,
                    TestLabel "matchIdentifier Test3"   testMatchIdentifier3,
                    TestLabel "matchIdentifier Test4"   testMatchIdentifier4,
                    TestLabel "matchIdentifier Test5"   testMatchIdentifier5,
                    TestLabel "matchIdentifier Test6"   testMatchIdentifier6,
                    TestLabel "matchIdentifier Test7"   testMatchIdentifier7,
                    TestLabel "matchIdentifier Test8"   testMatchIdentifier8,
                    TestLabel "matchIdentifier Test9"   testMatchIdentifier9,
                    TestLabel "matchIdentifier Test10"  testMatchIdentifier10,
                    TestLabel "matchIdentifier Test11"  testMatchIdentifier11,
                    TestLabel "matchIdentifier Test12"  testMatchIdentifier12,
                    TestLabel "matchIdentifier Test13"  testMatchIdentifier13,
                    TestLabel "matchIdentifier Test14"  testMatchIdentifier14,
                    TestLabel "matchIdentifier Test15"  testMatchIdentifier15,
                    TestLabel "matchIdentifier Test16"  testMatchIdentifier16,
                    TestLabel "matchIdentifier Test17"  testMatchIdentifier17,
                    TestLabel "matchIdentifier Test18"  testMatchIdentifier18,
                    TestLabel "matchIdentifier Test19"  testMatchIdentifier19,
                    TestLabel "matchIdentifier Test20"  testMatchIdentifier20,
                    TestLabel "matchIdentifier Test21"  testMatchIdentifier21,
                    TestLabel "matchIdentifier Test22"  testMatchIdentifier22,
                    TestLabel "matchIdentifier Test23"  testMatchIdentifier23,
                    TestLabel "matchIdentifier Test24"  testMatchIdentifier24,
                    TestLabel "matchIdentifier Test25"  testMatchIdentifier25,
                    TestLabel "matchIdentifier Test26"  testMatchIdentifier26,
                    TestLabel "matchIdentifier Test27"  testMatchIdentifier27
                 ]
