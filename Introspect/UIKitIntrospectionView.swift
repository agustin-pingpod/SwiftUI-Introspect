#if canImport(UIKit)
import UIKit
import SwiftUI

/// Introspection UIView that is inserted alongside the target view.
public class IntrospectionUIView: UIView {
    
    var moveToWindowHandler: ((IntrospectionUIView) -> Void)?
    
    required init() {
        super.init(frame: .zero)
        isHidden = true
        isUserInteractionEnabled = false
    }
    
    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func didMoveToWindow() {
        super.didMoveToWindow()
        moveToWindowHandler?(self)
    }
}

/// Introspection View that is injected into the UIKit hierarchy alongside the target view.
/// After `updateUIView` is called, it calls `selector` to find the target view, then `customize` when the target view is found.
public struct UIKitIntrospectionView<TargetViewType: UIView>: UIViewRepresentable {
    
    /// Method that introspects the view hierarchy to find the target view.
    /// First argument is the introspection view itself, which is contained in a view host alongside the target view.
    let selector: (IntrospectionUIView) -> TargetViewType?
    
    /// User-provided customization method for the target view.
    let customize: (TargetViewType) -> Void
    
    public init(
        selector: @escaping (IntrospectionUIView) -> TargetViewType?,
        customize: @escaping (TargetViewType) -> Void
    ) {
        self.selector = selector
        self.customize = customize
    }

    private func notify(_ view: IntrospectionUIView) {
        guard
            view.window != nil,
            let targetView = selector(view)
        else {
            return
        }
        customize(targetView)
    }
    
    /// When `makeUIView` and `updateUIView` are called, the Introspection view is not yet in the UIKit hierarchy.
    /// At this point, `introspectionView.superview.superview` is nil and we can't access the target UIKit view.
    /// To workaround this, we wait until the runloop is done inserting the introspection view in the hierarchy, then run the selector.
    /// Finding the target view fails silently if the selector yields no result. This happens when the introspection view gets
    /// removed from the hierarchy.
    public func makeUIView(context: Context) -> IntrospectionUIView {
        let view = IntrospectionUIView()
        view.accessibilityLabel = "IntrospectionUIView<\(TargetViewType.self)>"
        view.moveToWindowHandler = {
            self.notify($0)
        }
        return view
    }
    
    /// SwiftUI state changes after `makeUIView` will trigger this function, not
    /// `makeUIView`, so we need to call the handler again to allow re-customization
    /// based on the newest state.
    public func updateUIView(_ view: IntrospectionUIView, context: Context) {
        DispatchQueue.main.async {
            self.notify(view)
        }
    }
    
    /// Avoid memory leaks.
    public static func dismantleUIView(_ view: IntrospectionUIView, coordinator: ()) {
        view.moveToWindowHandler = nil
    }
}
#endif
