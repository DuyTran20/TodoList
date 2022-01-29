import ComposableArchitecture
import SwiftUI
import UIKit


final class RootViewController: UIViewController {
  
  private let store: Store<RootState, RootAction>
  
  private let viewStore: ViewStore<ViewState, ViewAction>
  
  var disposables = CompositeDisposable()
  
  private var viewController = UIViewController() {
    willSet {
      viewController.willMove(toParent: nil)
      viewController.view.removeFromSuperview()
      viewController.removeFromParent()
      addChild(newValue)
      newValue.view.frame = self.view.frame
      view.addSubview(newValue.view)
      newValue.didMove(toParent: self)
    }
  }
  
  
  init(store: Store<RootState, RootAction>? = nil) {
    let unwrapStore = store ?? Store(initialState: RootState(), reducer: RootReducer, environment: RootEnvironment())
    self.store = unwrapStore
    self.viewStore = ViewStore(unwrapStore.scope(state: ViewState.init, action: RootAction.init))
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .white
    viewStore.send(.viewDidLoad)
    disposables += viewStore.publisher.rootScreen.producer.startWithValues { [weak self] screen in
      guard let self = self else {return}
      switch screen {
      case .main:
        let vc = MainViewController(store: self.store.scope(state: \.mainState, action: RootAction.mainAction))
        let nav = UINavigationController(rootViewController: vc)
        self.viewController = nav
      case .auth:
        let vc = AuthViewController(store: self.store.scope(state: \.authState, action: RootAction.authAction))
        self.viewController = vc
      }
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    viewStore.send(.viewWillAppear)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    viewStore.send(.viewWillDisappear)
  }
  
}

fileprivate struct ViewState: Equatable {
  var rootScreen: RootScreen = .auth
  init(state: RootState) {
    self.rootScreen = state.rootScreen
  }
}

fileprivate enum ViewAction: Equatable {
  case viewDidLoad
  case viewWillAppear
  case viewWillDisappear
  case none
  
  init(action: RootAction) {
    switch action {
    case .viewDidLoad:
      self = .viewDidLoad
    case .viewWillAppear:
      self = .viewWillAppear
    case .viewWillDisappear:
      self = .viewWillDisappear
    default:
      self = .none
    }
  }
}

fileprivate extension RootState {
  
  var viewState: ViewState {
    get {
      ViewState(state: self)
    }
    set {
      
    }
  }
  
}

fileprivate extension RootAction {
  
  init(action: ViewAction) {
    switch action {
    case .viewDidLoad:
      self = .viewDidLoad
    case .viewWillAppear:
      self = .viewWillAppear
    case .viewWillDisappear:
      self = .viewWillDisappear
    default:
      self = .none
    }
  }
}
