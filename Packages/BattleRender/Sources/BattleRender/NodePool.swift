import SpriteKit

final class NodePool<Node: SKNode> {
    private var pool: [Node] = []
    private let factory: () -> Node
    private let reset: (Node) -> Void

    init(factory: @escaping () -> Node, reset: @escaping (Node) -> Void = { _ in }) {
        self.factory = factory
        self.reset = reset
    }

    @MainActor
    func acquire() -> Node {
        if let node = pool.popLast() {
            node.isHidden = false
            return node
        }
        return factory()
    }

    @MainActor
    func release(_ node: Node) {
        reset(node)
        node.removeFromParent()
        node.isHidden = true
        pool.append(node)
    }
}
