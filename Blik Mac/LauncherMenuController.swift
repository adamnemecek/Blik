//
//  LauncherMenuController.swift
//  Blik
//
//  Created by Patrick Smith on 12/11/2015.
//  Copyright © 2015 Burnt Caramel. All rights reserved.
//

import Foundation
import BurntFoundation
import BurntCocoaUI


private enum Item {
	case nowProject
	case project(GLAProject)
	case allProjects
	case newProject
	case showInDock
	case preferences
	case quit
}

extension Item: UIChoiceRepresentative {
	typealias UniqueIdentifier = String
	var uniqueIdentifier: UniqueIdentifier {
		switch self {
		case .nowProject:
			return "now"
		case let .project(project):
			return "project.\(project.uuid)"
		case .allProjects:
			return "allProjects"
		case .newProject:
			return "newProject"
		case .showInDock: return "showInDock"
		case .preferences: return "preferences"
		case .quit: return "quit"
		}
	}
	
	var title: String {
		switch self {
		case .nowProject:
			return "Now"
		case let .project(project):
			return project.name
		case .allProjects:
			return NSLocalizedString("All Projects…", comment: "Title for opening All Projects")
		case .newProject:
			return NSLocalizedString("New Project…", comment: "Title for creating a new project")
		case .showInDock:
			return NSLocalizedString("Show in Dock", comment: "Title for toggling Dock icon")
		case .preferences:
			return NSLocalizedString("Preferences…", comment: "Title for opening the preferences")
		case .quit:
			return NSLocalizedString("Quit Blik", comment: "Title for quitting the app")
		}
	}
}

extension Item {
	var action: Selector? {
		switch self {
		case .nowProject:
			return nil
		case .project:
			return #selector(LauncherMenuController.openProject(_:))
		case .allProjects:
			return #selector(LauncherMenuController.goToAllProjects(_:))
		case .newProject:
			return #selector(LauncherMenuController.createNewProject(_:))
		case .showInDock:
			return #selector(LauncherMenuController.toggleShowInDock(_:))
		case .preferences:
			return #selector(LauncherMenuController.showPreferences(_:))
		case .quit:
			return #selector(LauncherMenuController.terminateApp(_:))
		}
	}
}

open class LauncherMenuController: NSObject {
	fileprivate let projectManager: GLAProjectManager
	fileprivate let navigator: GLAMainSectionNavigator
	fileprivate let allProjectsUser: GLALoadableArrayUsing
	fileprivate let menuAssistant: MenuAssistant<Item>
	fileprivate let projectMenuControllerCache = NSCache<NSUUID, LauncherProjectMenuController>()
	fileprivate let projectManagerObserver: AnyNotificationObserver
	fileprivate let nowWidgetViewController: NowWidgetViewController
	
	public init(menu: NSMenu, projectManager: GLAProjectManager, navigator: GLAMainSectionNavigator) {
		self.projectManager = projectManager
		self.navigator = navigator
		
		allProjectsUser = projectManager.useAllProjects()
		projectManagerObserver = AnyNotificationObserver(object: projectManager)
		
		menuAssistant = MenuAssistant(menu: menu)
		
		nowWidgetViewController = NowWidgetViewController(nibName: "NowWidgetViewController", bundle: nil)!
		
		super.init()
		
		menu.delegate = self
		
		menuAssistant.customization.actionAndTarget = { [weak self] (item) in
			return (item.action, self)
		}
		
		/*menuAssistant.customization.state = { (item) in
			switch item {
			case let .Project(project):
				if project.UUID == projectManager.nowProject?.UUID {
					return NSOnState
				}
			case .showInDock:
				let settings = GLAApplicationSettingsManager.sharedApplicationSettingsManager()
				return settings.hidesDockIcon ? NSOnState : NSOffState
			default: break
			}
			
			return NSOffState
		}*/
		
		menuAssistant.customization.additionalSetUp = { item, menuItem in
			switch item {
			case .nowProject:
				menuItem.view = self.nowWidgetViewController.view
			case .project:
				if menuItem.submenu == nil {
					menuItem.submenu = NSMenu()
				}
			default:
				break
			}
		}
		
		allProjectsUser.changeCompletionBlock = { [weak self] _ in
			self?.reloadMenu()
		}
		
		projectManagerObserver.observe(NSNotification.Name.GLAProjectManagerNowProjectDidChange.rawValue) { [weak self] _ in
			self?.reloadMenu()
		}
		
		reloadMenu()
	}
	
	open var menu: NSMenu {
		return menuAssistant.menu
	}
	
	fileprivate var items: [Item?] {
		var items = [Item?]()
		
		if projectManager.nowProject != nil {
			items.append(.nowProject)
			items.append(nil)
		}
		
		let projects = (allProjectsUser.copyChildrenLoadingIfNeeded() as! [GLAProject]?) ?? []
		let projectItems: [Item?] = projects.filter{ !$0.hideFromLauncherMenu }.map(Item.project)
		items += projectItems
		
		items.append(nil)
		if projects.count > 0 {
			items.append(.allProjects)
		}
		items.append(.newProject)
		
		items.append(nil)
		items.append(.showInDock)
		items.append(.preferences)
		items.append(.quit)
		
		return items
	}
	
	fileprivate func reloadMenu() {
		projectManager.loadNowProjectIfNeeded()
		
		menuAssistant.menuItemRepresentatives = self.items
		menuAssistant.update()
	}
}

extension LauncherMenuController {
	fileprivate func activateApplication() {
		NSApp.activate(ignoringOtherApps: true)
	}
	
	@IBAction func openProject(_ menuItem: NSMenuItem) {
		guard let
      item = menuAssistant.itemRepresentative(for: menuItem),
			case let .project(project) = item
			else { return }
		
		navigator.go(to: project)
	
		activateApplication()
	}
	
	@IBAction func createNewProject(_ menuItem: NSMenuItem) {
		navigator.addNewProject()
	
		activateApplication()
	}
	
	@IBAction func goToAllProjects(_ menuItem: NSMenuItem) {
		navigator.goToAllProjects()
	
		activateApplication()
	}
	
	@IBAction func toggleShowInDock(_ menuItem: NSMenuItem) {
		let settings = GLAApplicationSettingsManager.shared()
		settings?.toggleHidesDockIcon(menuItem)
	}
	
	@IBAction func showPreferences(_ menuItem: NSMenuItem) {
		GLAPreferencesWindowController.showWindow()
		activateApplication()
	}
	
	@IBAction func terminateApp(_ menuItem: NSMenuItem) {
		NSApp.terminate(menuItem)
	}
}

extension LauncherMenuController: NSMenuDelegate {
	public func menu(_ menu: NSMenu, willHighlight menuItem: NSMenuItem?) {
		guard let menuItem = menuItem else { return }
		
    guard let item = menuAssistant.itemRepresentative(for: menuItem) else { return }
		
		if case let .project(project) = item {
			let submenu = menuItem.submenu ?? {
				let submenu = NSMenu()
				menuItem.submenu = submenu
				return submenu
			}()
			
      let menuController = projectMenuControllerCache.object(forKey: project.uuid as NSUUID) ?? {
				let menuController = LauncherProjectMenuController(menu: submenu, project: project, projectManager: projectManager, navigator: navigator)
				projectMenuControllerCache.setObject(menuController, forKey: project.uuid as NSUUID)
				return menuController
			}()
			
			menuController.update()
		}
	}
}

extension LauncherMenuController: NSUserInterfaceValidations {
	public func validateUserInterfaceItem(_ anItem: NSValidatedUserInterfaceItem) -> Bool {
		guard let
			menuItem = anItem as? NSMenuItem,
      let item = menuAssistant.itemRepresentative(for: menuItem)
			else { return true }
		
		var state = NSOffState
		
		switch item {
		case let .project(project):
			if project.uuid == projectManager.nowProject?.uuid {
				state = NSOnState
			}
		case .showInDock:
			let settings = GLAApplicationSettingsManager.shared()
			state = (settings?.hidesDockIcon)! ? NSOffState : NSOnState
		default: break
		}
		
		menuItem.state = state
		
		return true
	}
}
