import UIKit
import MixinServices

protocol HomeAppsManagerDelegate: AnyObject {
    
    func homeAppsManagerDidUpdateItems(_ manager: HomeAppsManager)
    func homeAppsManagerDidEnterEditingMode(_ manager: HomeAppsManager)
    func homeAppsManagerDidLeaveEditingMode(_ manager: HomeAppsManager)
    func homeAppsManager(_ manager: HomeAppsManager, didSelectApp app: HomeApp)
    func homeAppsManager(_ manager: HomeAppsManager, didMoveToPage page: Int)
    func homeAppsManager(_ manager: HomeAppsManager, didUpdatePageCount pageCount: Int)
    func homeAppsManager(_ manager: HomeAppsManager, didBeginFolderDragOutWithTransfer transfer: HomeAppsDragInteractionTransfer)
    
}

class HomeAppsManager: NSObject {
    
    let feedback = UIImpactFeedbackGenerator()
    
    weak var delegate: HomeAppsManagerDelegate?
    
    unowned let viewController: UIViewController
    unowned let candidateCollectionView: UICollectionView
    unowned let pinnedCollectionView: UICollectionView?
    
    var items: [[HomeAppItem]] {
        didSet {
            delegate?.homeAppsManager(self, didUpdatePageCount: items.count)
            delegate?.homeAppsManagerDidUpdateItems(self)
        }
    }
    var pinnedItems: [HomeApp] {
        didSet {
            delegate?.homeAppsManagerDidUpdateItems(self)
        }
    }
    var isEditing = false
    
    var longPressRecognizer = UILongPressGestureRecognizer()
    var currentDragInteraction: HomeAppsDragInteraction?
    var currentFolderInteraction: HomeAppsFolderInteraction?
    var openFolderInfo: HomeAppsOpenFolderInfo?
    var ignoreDragOutOnTop = false
    var ignoreDragOutOnBottom = false
    
    var isInAppsFolderViewController: Bool {
        pinnedCollectionView == nil
    }
    
    var currentPage: Int {
        if items.isEmpty || candidateCollectionView.frame.size.width == 0 {
            return 0
        } else {
            return Int(candidateCollectionView.contentOffset.x) / Int(candidateCollectionView.frame.size.width)
        }
    }
    
    var currentPageCell: AppPageCell? {
        guard !items.isEmpty else {
            return nil
        }
        let visibleCells = candidateCollectionView.visibleCells
        if visibleCells.count == 0 {
            return candidateCollectionView.subviews.first as? AppPageCell
        } else {
            return visibleCells.first as? AppPageCell
        }
    }
    
    weak var pageTimer: Timer?
    weak var folderTimer: Timer?
    weak var folderRemoveTimer: Timer?
    
    private let tapRecognizer = UITapGestureRecognizer()
        
    init(
        viewController: UIViewController,
        candidateCollectionView: UICollectionView,
        items: [[HomeAppItem]] = [[]],
        pinnedCollectionView: UICollectionView? = nil,
        pinnedItems: [HomeApp] = []
    ) {
        self.viewController = viewController
        self.candidateCollectionView = candidateCollectionView
        self.pinnedCollectionView = pinnedCollectionView
        self.items = items
        self.pinnedItems = pinnedItems
        
        super.init()
        
        if let flowLayout = candidateCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.itemSize = pinnedCollectionView != nil ? HomeAppsMode.regular.pageSize : HomeAppsMode.folder.pageSize
        }
        if let flowLayout = pinnedCollectionView?.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.itemSize = HomeAppsMode.pinned.pageSize
        }
        candidateCollectionView.dataSource = self
        candidateCollectionView.delegate = self
        pinnedCollectionView?.dataSource = self
        pinnedCollectionView?.delegate = self
        longPressRecognizer.addTarget(self, action: #selector(handleLongPressGesture(_:)))
        self.viewController.view.addGestureRecognizer(longPressRecognizer)
        tapRecognizer.isEnabled = false
        tapRecognizer.delegate = self
        tapRecognizer.cancelsTouchesInView = false
        tapRecognizer.addTarget(self, action: #selector(handleTapGesture(gestureRecognizer:)))
        self.viewController.view.addGestureRecognizer(tapRecognizer)
        NotificationCenter.default.addObserver(self, selector: #selector(leaveEditingMode), name: UIApplication.willResignActiveNotification, object: nil)
    }
    
    func reloadData(pinnedItems: [HomeApp], candidateItems: [[HomeAppItem]]) {
        self.items = candidateItems
        self.pinnedItems = pinnedItems
        candidateCollectionView.reloadData()
        pinnedCollectionView?.reloadData()
    }
    
}

extension HomeAppsManager {
    
    @objc func handleTapGesture(gestureRecognizer: UITapGestureRecognizer) {
        guard isEditing else {
            return
        }
        var touchPoint = gestureRecognizer.location(in: viewController.view)
        guard let (collectionView, pageCell) = collectionViewAndPageCell(at: touchPoint) else {
            return
        }
        touchPoint = gestureRecognizer.location(in: collectionView)
        touchPoint.x -= collectionView.contentOffset.x
        if pageCell.collectionView.indexPathForItem(at: touchPoint) == nil {
            leaveEditingMode()
        }
    }
    
    func collectionViewAndPageCell(at point: CGPoint) -> (collectionView: UICollectionView, cell: AppPageCell)? {
        let collectionView: UICollectionView
        if let pinnedCollectionView = pinnedCollectionView, pinnedCollectionView.frame.contains(viewController.view.convert(point, to: pinnedCollectionView)) {
            collectionView = pinnedCollectionView
        } else {
            collectionView = candidateCollectionView
        }
        let convertedPoint = viewController.view.convert(point, to: collectionView)
        if let indexPath = collectionView.indexPathForItem(at: convertedPoint), let cell = collectionView.cellForItem(at: indexPath) as? AppPageCell {
            return (collectionView, cell)
        } else if let cell = collectionView.visibleCells.first as? AppPageCell {
            return (collectionView, cell)
        } else {
            return nil
        }
    }
    
    func enterEditingMode(occurHaptic: Bool = true) {
        guard !isEditing else {
            return
        }
        isEditing = true
        if occurHaptic {
            feedback.impactOccurred()
        }
        for case let cell as AppPageCell in candidateCollectionView.visibleCells + (pinnedCollectionView?.visibleCells ?? []) {
            cell.enterEditingMode()
        }
        // Add an empty page
        if let lastPage = items.last, lastPage.count > 0 {
            items.append([])
            candidateCollectionView.insertItems(at: [IndexPath(item: items.count - 1, section: 0)])
        }
        tapRecognizer.isEnabled = true
        delegate?.homeAppsManagerDidEnterEditingMode(self)
    }
    
    @objc func leaveEditingMode() {
        guard isEditing else {
            return
        }
        isEditing = false
        for case let cell as AppPageCell in candidateCollectionView.visibleCells + (pinnedCollectionView?.visibleCells ?? []) {
            cell.leaveEditingMode()
        }
        // Remove empty page
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            let emptyIndex = self.items.enumerated().compactMap( { $1.count == 0 ? $0 : nil })
            self.items.remove(at: emptyIndex)
            self.candidateCollectionView.performBatchUpdates({
                self.candidateCollectionView.deleteItems(at: emptyIndex.map({ IndexPath(item: $0, section: 0) }))
            }, completion: nil)
        }
        tapRecognizer.isEnabled = false
        delegate?.homeAppsManagerDidLeaveEditingMode(self)
    }
    
    // Update items for current page after end drag
    func updateState(forPageCell pageCell: AppPageCell) {
        if let pinnedCollectionView = pinnedCollectionView, pinnedCollectionView.visibleCells.contains(pageCell) {
            let items = pageCell.collectionView.visibleCells.compactMap { ($0 as? AppCell)?.app }
            pinnedItems = items
            pageCell.items = items.map { .app($0) }
        } else {
            guard let pageIndexPath = candidateCollectionView.indexPath(for: pageCell) else {
                return
            }
            let items = pageCell.collectionView.visibleCells.compactMap { ($0 as? HomeAppCell)?.item }
            self.items[pageIndexPath.row] = items
            pageCell.items = items
        }
    }
    
    // Moves last item in page to next and rearranges next pages if needed
    func moveLastItem(inPage page: Int) {
        guard page + 1 < items.count else {
            return
        }
        var currentPageItems = items[page + 1]
        currentPageItems.insert(items[page].removeLast(), at: 0)
        items[page + 1] = currentPageItems
        let appsPerPage = isInAppsFolderViewController ? HomeAppsMode.folder.appsPerPage : HomeAppsMode.regular.appsPerPage
        if currentPageItems.count > appsPerPage {
            moveLastItem(inPage: page + 1)
        }
    }
    
    func perform(transfer: HomeAppsDragInteractionTransfer) {
        viewController.view.removeGestureRecognizer(longPressRecognizer)
        longPressRecognizer = transfer.gestureRecognizer
        longPressRecognizer.removeTarget(nil, action: nil)
        longPressRecognizer.addTarget(self, action: #selector(handleLongPressGesture(_:)))
        viewController.view.addGestureRecognizer(longPressRecognizer)
        currentDragInteraction = transfer.interaction.copy()
        currentDragInteraction?.needsUpdate = true
        let placeholderView = transfer.interaction.placeholderView
        placeholderView.center = viewController.view.convert(placeholderView.center, from: placeholderView.superview)
        viewController.view.addSubview(placeholderView)
    }
    
    func invalidatePageTimer() {
        pageTimer?.invalidate()
        pageTimer = nil
    }
    
    func invalidateFolderTimer() {
        folderTimer?.invalidate()
        folderTimer = nil
    }
    
    func invalidateFolderRemoveTimer() {
        folderRemoveTimer?.invalidate()
        folderRemoveTimer = nil
    }
    
}

extension HomeAppsManager: UICollectionViewDataSource, UICollectionViewDelegate {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView == candidateCollectionView {
            return items.count
        } else {
            return 1
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let items = collectionView == candidateCollectionView ? items[indexPath.row] : pinnedItems.map { .app($0) }
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: R.reuseIdentifier.app_page, for: indexPath)!
        cell.items = items
        cell.draggedItem = currentDragInteraction?.item
        cell.delegate = self
        cell.collectionView.reloadData()
        if isInAppsFolderViewController {
            cell.mode = .folder
        } else {
            cell.mode = collectionView == candidateCollectionView ? .regular : .pinned
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? AppPageCell else {
            return
        }
        if let currentInteraction = currentDragInteraction, currentInteraction.needsUpdate {
            cell.items = items[indexPath.row]
            currentInteraction.currentPageCell = cell
            currentInteraction.currentIndexPath = IndexPath(item: cell.collectionView(cell.collectionView, numberOfItemsInSection: 0) - 1, section: 0)
            currentInteraction.needsUpdate = false
        }
        cell.draggedItem = currentDragInteraction?.item
        cell.collectionView.reloadData()
        if isEditing {
            cell.enterEditingMode()
        } else {
            cell.leaveEditingMode()
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let cell = cell as? AppPageCell, isEditing else {
            return
        }
        cell.leaveEditingMode()
    }
    
}

extension HomeAppsManager: UIScrollViewDelegate {
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let page = scrollView.contentOffset.x / scrollView.frame.width
        delegate?.homeAppsManager(self, didMoveToPage: Int(round(Float(page))))
    }
    
}

extension HomeAppsManager: AppPageCellDelegate {
    
    func appPageCell(_ pageCell: AppPageCell, didSelect cell: HomeAppCell) {
        if let cell = cell as? AppFolderCell {
            showFolder(from: cell)
        } else if let cell = cell as? AppCell {
            if !isEditing, let app = cell.app {
                delegate?.homeAppsManager(self, didSelectApp: app)
            }
        }
    }
    
}

extension HomeAppsManager: UIGestureRecognizerDelegate {
    
    // Disable tag when clear button tapped in folder controller
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        !(touch.view is UIButton)
    }
    
}
