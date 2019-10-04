import Foundation

typealias GamePosition = (x:Int, y:Int)

enum GamePlayerType:String {
    case human = "human"
    case ai = "ai"
}

enum GameMode:String {
    case put = "put"
    case move = "move"
}

enum GamePlayer:String {
    case x = "x"
    case o = "o"
}

enum GameAction {
    case put(at:GamePosition)
    case move(from:GamePosition, to:GamePosition)
}

struct GameState {
    let currPlayer:GamePlayer
    let mode:GameMode
    let board:[[String]]
    
    init() {
        self.init(currPlayer: arc4random_uniform(2) == 0 ? .x : .o,
                  mode: .put,
                  board: [["","",""],["","",""],["","",""]])
    }
    
    private init(currPlayer:GamePlayer,
                 mode:GameMode,
                 board:[[String]]) {
        self.currPlayer = currPlayer
        self.mode = mode
        self.board = board
    }
    
    func makeMove(action:GameAction) -> GameState? {
        switch action {
        case .put(let at):
            guard case .put = mode,
                  board[at.x][at.y] == "" else { return nil }
            
            var newBoard = board
            newBoard[at.x][at.y] = currPlayer.rawValue
            
            let numSquaredUsed = newBoard.reduce(0, {
                return $1.reduce($0, { return $0 + ($1 != "" ? 1 : 0) })
            })
            
            return GameState(currPlayer: currPlayer == .x ? .o : .x,
                             mode: numSquaredUsed >= 6 ? .move : .put,
                             board: newBoard)
            
        case .move(let from, let to):

            guard case .move = mode,
                  board[from.x][from.y] == currPlayer.rawValue,
                  board[to.x][to.y] == "" else { return nil }
            
            var newBoard = board
            newBoard[from.x][from.y] = ""
            newBoard[to.x][to.y] = currPlayer.rawValue
            return GameState(currPlayer: currPlayer == .x ? .o : .x,
                             mode: .move,
                             board: newBoard)
            
        }
    }
    
    var checkWinner:GamePlayer? {
        get {
            for l in 0..<3 {
                if board[l][0] != "" &&
                    board[l][0] == board[l][1] && board[l][0] == board[l][2] {
                    return GamePlayer(rawValue: board[l][0])
                    
                }
                if board[0][l] != "" &&
                    board[0][l] == board[1][l] && board[0][l] == board[2][l] {
                    return GamePlayer(rawValue: board[0][l])
                    
                }
            }
            if board[0][0] != "" &&
                board[0][0] == board[1][1] && board[0][0] == board[2][2] {
                return GamePlayer(rawValue: board[0][0])
                
            }
            if board[0][2] != "" &&
                board[0][2] == board[1][1] && board[0][2] == board[2][0] {
                return GamePlayer(rawValue: board[0][2])
            }
            return nil
        }
    }
}
