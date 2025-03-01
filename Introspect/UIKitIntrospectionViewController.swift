#if canImport(UIKit)
import SwiftUI
import UIKit

/// Introspection UIViewController that is inserted alongside the target view controller.
public class IntrospectionUIViewController: UIViewController {

    var moveToWindowHandler: ((IntrospectionUIViewController) -> Void)?

    required init() {
        super.init(nibName: nil, bundle: nil)
        let introspectionView = IntrospectionUIView()
        self.view = introspectionView

        introspectionView.moveToWindowHandler = { [weak self] _ in
            self?.viewDidMoveToWindow()
        }
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func viewDidMoveToWindow() {
        moveToWindowHandler?(self)
    }
}

/// This is the same logic as IntrospectionView but for view controllers. Please see details above.
public struct UIKitIntrospectionViewController<TargetViewControllerType: UIViewController>: UIViewControllerRepresentable {

    /// Method that introspects the view hierarchy to find the target view controller.
    /// First argument is the introspection view controller itself.
    let selector: (IntrospectionUIViewController) -> TargetViewControllerType?

    /// User-provided customization method for the target view controller.
    let customize: (TargetViewControllerType) -> Void
    
    public init(
        selector: @escaping (IntrospectionUIViewController) -> TargetViewControllerType?,
        customize: @escaping (TargetViewControllerType) -> Void
    ) {
        self.selector = selector
        self.customize = customize
    }

    private func notify(_ viewController: IntrospectionUIViewController) {
        guard
            viewController.isViewLoaded,
            viewController.view.window != nil,
            let targetViewController = selector(viewController)
        else {
            return
        }
        customize(targetViewController)
    }
    
    /// When `makeUIViewController` and `updateUIViewController` are called, the Introspection view is not yet in
    /// the UIKit hierarchy. At this point, `introspectionViewController.parent` is nil and we can't access the target
    /// UIKit view controller. To workaround this, we wait until the runloop is done inserting the introspection view controller's
    /// view in the hierarchy, then run the selector. Finding the target view controller fails silently if the selector yields no result.
    /// This happens when the introspection view controller's view gets removed from the hierarchy.
    public func makeUIViewController(context: Context) -> IntrospectionUIViewController {
        let viewController = IntrospectionUIViewController()
        viewController.accessibilityLabel = "IntrospectionUIViewController<\(TargetViewControllerType.self)>"
        viewController.view.accessibilityLabel = "IntrospectionUIView<\(TargetViewControllerType.self)>"
        viewController.moveToWindowHandler = {
            self.notify($0)
        }
        return viewController
    }
    
    /// SwiftUI state changes after `makeUIViewController` will trigger this function, not
    /// `makeUIViewController`, so we need to call the handler again to allow re-customization
    /// based on the newest state.
    public func updateUIViewController(_ viewController: IntrospectionUIViewController, context: Context) {
        DispatchQueue.main.async {
            self.notify(viewController)
        }
    }

    /// Avoid memory leaks.
    public static func dismantleUIViewController(_ viewController: IntrospectionUIViewController, coordinator: ()) {
        viewController.moveToWindowHandler = nil
    }
}
#endif
