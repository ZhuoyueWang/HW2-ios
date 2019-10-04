import Foundation

private let MAX_ITERATIONS = 3
private let SCORE_WINNING = 100

struct GameAI {
    let game:GameState
    
    private func findPlayerPiece(playerIs player:GamePlayer?) -> [GamePosition] {
        var positions = [GamePosition]()
        for x in 0..<game.board.count {
            for y in 0..<game.board[x].count {
                if (player != nil && game.board[x][y] == player!.rawValue) ||
                   (player == nil && game.board[x][y].isEmpty) {
                    positions.append(GamePosition(x: x,
                                                  y: y))
                }
            }
        }
        return positions
    }
    
    private func possibleActions() -> [GameAction] {
        let emptySquares = findPlayerPiece(playerIs: nil)
                if game.mode == .put {
            return emptySquares.map { GameAction.put(at: $0) }
        }
        var actions = [GameAction]()
        for sourceSquare in findPlayerPiece(playerIs: game.currPlayer) {
            for destinationSquare in emptySquares {
                actions.append(.move(from: sourceSquare,
                                     to: destinationSquare))
            }
        }
        return actions
    }
    
    var nextAction:GameAction {
        return possibleActions()[0]
    }
}
