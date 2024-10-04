import SwiftUI

public struct CardItem: Identifiable {
    public let id = UUID()
    public let content: AnyView
    public let backgroundColor: AnyView

    public init(content: AnyView, backgroundColor: AnyView) {
        self.content = content
        self.backgroundColor = backgroundColor
    }
}

struct CardView: View {
    let content: AnyView
    let backgroundColor: AnyView

    var body: some View {
        content
            .frame(maxWidth: .infinity)
            .frame(height: UIScreen.main.bounds.height)
            .background(
            backgroundColor
                .cornerRadius(20)
                .shadow(radius: 10)
        )
    }
}

public struct WalletCardStack: View {
    public let cards: [CardItem]
    public let maxHeight: CGFloat = UIScreen.main.bounds.height
    public let minHeight: CGFloat
    public let cardSpacing: CGFloat = 60
    public let expandedSpacing: CGFloat = 100
    public let topOffset: CGFloat
    public let shouldLockWhenExpanded: Bool
    public let orderedExpansion: Bool

    @State private var cardStates: [CardState] = []
    @State private var activeExpandIndex: Int = 0
    @State private var isDraggingExpanded: Bool = false
    @State private var draggingCardIndex: Int = 0

    struct CardState {
        var offset: CGFloat
        var lastDragPosition: CGFloat
        var isExpanded: Bool = false
        var isLocked: Bool = false
    }

    public init(cards: [CardItem], shouldLockWhenExpanded: Bool = false, orderedExpansion: Bool = false) {
        self.cards = cards
        self.minHeight = UIScreen.main.bounds.height * 0.15
        self.topOffset = UIScreen.main.bounds.height * 0.1
        self.shouldLockWhenExpanded = shouldLockWhenExpanded
        self.orderedExpansion = orderedExpansion
    }

    public var body: some View {
        ZStack(alignment: .bottom) {
            ForEach(Array(cards.enumerated().reversed()), id: \.element.id) { index, card in
                CardView(content: card.content, backgroundColor: card.backgroundColor)
                    .offset(y: cardStates.isEmpty ? 0 : cardStates[index].offset)
                    .gesture(
                    DragGesture()
                        .onChanged { value in
                        if canHandleGesture(for: index) {
                            handleDrag(value, forCardAt: index)
                        }
                    }
                        .onEnded { value in
                        if canHandleGesture(for: index) {
                            handleDragEnd(value, forCardAt: index)
                        }
                    }
                )
                    .zIndex(Double(index))
            }
        }
            .onAppear {
            setupInitialState()
        }
    }

    private func canHandleGesture(for index: Int) -> Bool {
        if !shouldLockWhenExpanded {
            return true
        }
        return index >= activeExpandIndex && activeExpandIndex < cards.count
    }

    private func setupInitialState() {
        let initialStates = cards.enumerated().map { index, _ in
            let initialOffset = maxHeight - minHeight - CGFloat(cards.count - 1 - index) * cardSpacing - topOffset
            return CardState(offset: initialOffset, lastDragPosition: initialOffset)
        }
        cardStates = initialStates
        activeExpandIndex = 0
    }

    private func handleDrag(_ value: DragGesture.Value, forCardAt index: Int) {
        let translation = value.translation.height

        if !shouldLockWhenExpanded && cardStates[index].isExpanded {
            // Handle dragging of expanded cards
            if !isDraggingExpanded {
                isDraggingExpanded = true
                draggingCardIndex = index
            }

            // Calculate new position of the dragged card
            let baseOffset = cardStates[index].lastDragPosition
            let proposedOffset = baseOffset + translation
            let maxCollapsedOffset = maxHeight - minHeight - CGFloat(cards.count - 1 - index) * cardSpacing - topOffset
            let constrainedOffset = min(max(proposedOffset, topOffset + CGFloat(index) * expandedSpacing), maxCollapsedOffset)

            // Calculate drag progress
            let totalCollapseDistance = maxCollapsedOffset - (topOffset + CGFloat(index) * expandedSpacing)
            let currentProgress = (constrainedOffset - (topOffset + CGFloat(index) * expandedSpacing)) / totalCollapseDistance

            // Synchronize position of all affected cards
            for i in index..<cards.count {
                if cardStates[i].isExpanded {
                    let cardBaseOffset = topOffset + CGFloat(i) * expandedSpacing
                    let cardMaxCollapsedOffset = maxHeight - minHeight - CGFloat(cards.count - 1 - i) * cardSpacing - topOffset
                    let cardTotalDistance = cardMaxCollapsedOffset - cardBaseOffset
                    cardStates[i].offset = cardBaseOffset + cardTotalDistance * currentProgress
                }
            }
        } else {
            // Dragging logic for unexpanded cards remains unchanged
            let baseOffset = cardStates[activeExpandIndex].lastDragPosition
            let proposedOffset = baseOffset + translation
            let constrainedOffset = min(max(proposedOffset, topOffset), maxHeight - minHeight)
            cardStates[activeExpandIndex].offset = constrainedOffset
        }
    }

    private func handleDragEnd(_ value: DragGesture.Value, forCardAt index: Int) {
        let velocity = value.predictedEndTranslation.height - value.translation.height

        if !shouldLockWhenExpanded && cardStates[index].isExpanded {
            // Handle collapsing of expanded cards
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if velocity > 500 || cardStates[index].offset > maxHeight * 0.6 {
                    collapseCards(from: index)
                } else {
                    // Restore expanded position for all affected cards
                    for i in index..<cards.count {
                        if cardStates[i].isExpanded {
                            cardStates[i].offset = topOffset + CGFloat(i) * expandedSpacing
                            cardStates[i].lastDragPosition = cardStates[i].offset
                        }
                    }
                }
            }
            isDraggingExpanded = false
        } else {
            // Expand logic for unexpanded cards remains unchanged
            let currentOffset = cardStates[activeExpandIndex].offset
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if velocity < -500 || currentOffset < maxHeight * 0.4 {
                    expandCurrentCard()
                } else {
                    resetUnexpandedCards()
                }
            }
        }
    }

    private func expandCurrentCard() {
        cardStates[activeExpandIndex].isExpanded = true
        let targetOffset = topOffset + CGFloat(activeExpandIndex) * expandedSpacing

        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            cardStates[activeExpandIndex].offset = targetOffset
            cardStates[activeExpandIndex].lastDragPosition = targetOffset

            if shouldLockWhenExpanded {
                cardStates[activeExpandIndex].isLocked = true
            }

            for i in (activeExpandIndex + 1)..<cards.count {
                let collapsedPosition = maxHeight - minHeight - CGFloat(cards.count - 1 - i) * cardSpacing - topOffset
                cardStates[i].offset = collapsedPosition
                cardStates[i].lastDragPosition = collapsedPosition
            }
        }

        activeExpandIndex += 1
    }

    private func collapseCards(from index: Int) {
        for i in index..<cards.count {
            cardStates[i].isExpanded = false
            cardStates[i].isLocked = false
            let collapsedPosition = maxHeight - minHeight - CGFloat(cards.count - 1 - i) * cardSpacing - topOffset
            cardStates[i].offset = collapsedPosition
            cardStates[i].lastDragPosition = collapsedPosition
        }
        activeExpandIndex = index
    }

    private func resetUnexpandedCards() {
        let collapsedPosition = maxHeight - minHeight - CGFloat(cards.count - 1 - activeExpandIndex) * cardSpacing - topOffset
        cardStates[activeExpandIndex].offset = collapsedPosition
        cardStates[activeExpandIndex].lastDragPosition = collapsedPosition
    }
}
