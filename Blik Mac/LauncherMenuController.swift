//
//  LauncherMenuController.swift
//  Blik
//
//  Created by Patrick Smith on 12/11/2015.
//  Copyright © 2015 Burnt Caramel. All rights reserved.
//

import Foundation
import BurntCocoaUI


private enum Item {
	case Project(GLAProject)
	case AllProjects
	case NewProject
}

extension Item: UIChoiceRepresentative {
	typealias UniqueIdentifier = String
	var uniqueIdentifier: UniqueIdentifier {
		switch self {
		case let .Project(project):
			return "project.\(project.UUID)"
		case .AllProjects:
			return "allProjects"
		case .NewProject:
			return "newProject"
		}
	}
	
	var title: String {
		switch self {
		case let .Project(project):
			return project.name
		case .AllProjects:
			return NSLocalizedString("All Projects…", comment: "Title for opening All Projects")
		case .NewProject:
			return NSLocalizedString("New Project…", comment: "Title for creating a new project")
		}
	}
}

public class LauncherMenuController: NSObject {
	private let projectManager: GLAProjectManager
	private let navigator: GLAMainSectionNavigator
	private let allProjectsUser: GLALoadableArrayUsing
	private let menuAssistant: MenuAssistant<Item>
	private let projectMenuControllerCache = NSCache()
	
	public init(menu: NSMenu, projectManager: GLAProjectManager, navigator: GLAMainSectionNavigator) {
		self.projectManager = projectManager
		self.navigator = navigator
		
		allProjectsUser = projectManager.useAllProjects()
		
		menuAssistant = MenuAssistant(menu: menu)
		
		super.init()
		
		menu.delegate = self
		
		menuAssistant.customization.actionAndTarget = { [weak self] (item) in
			let action: Selector
			
			switch item {
			case .Project:
				action = "openProject:"
			case .AllProjects:
				action = "goToAllProjects:"
			case .NewProject:
				action = "createNewProject:"
			}
			
			return (action, self)
		}
		
		menuAssistant.customization.additionalSetUp = { item, menuItem in
			if case .Project = item {
				if menuItem.submenu == nil {
					menuItem.submenu = NSMenu()
				}
			}
		}
		
		allProjectsUser.changeCompletionBlock = { [weak self] (inspector) in
			self?.reloadMenu()
		}
		
		reloadMenu()
	}
	
	public var menu: NSMenu {
		return menuAssistant.menu
	}
	
	private var items: [Item?] {
		let projects = (allProjectsUser.copyChildrenLoadingIfNeeded() as! [GLAProject]?) ?? []
		var items: [Item?] = projects.filter({ !$0.hideFromLauncherMenu }).map(Item.Project)
		
		items.append(nil)
		items.append(Item.AllProjects)
		items.append(Item.NewProject)
		
		return items
	}
	
	private func reloadMenu() {
		menuAssistant.menuItemRepresentatives = items
		menuAssistant.update()
	}
}

extension LauncherMenuController {
	private func activateApplication() {
		NSApp.activateIgnoringOtherApps(true)
	}
	
	@IBAction func openProject(menuItem: NSMenuItem) {
		guard let
			item = menuAssistant.itemRepresentativeForMenuItem(menuItem),
			case let .Project(project) = item
			else { return }
		
		navigator.goToProject(project)
	
		activateApplication()
	}
	
	@IBAction func createNewProject(menuItem: NSMenuItem) {
		navigator.addNewProject()
	
		activateApplication()
	}
	
	@IBAction func goToAllProjects(menuItem: NSMenuItem) {
		navigator.goToAllProjects()
	
		activateApplication()
	}
}

extension LauncherMenuController: NSMenuDelegate {
	public func menu(menu: NSMenu, willHighlightItem menuItem: NSMenuItem?) {
		guard let menuItem = menuItem else { return }
		
		guard let item = menuAssistant.itemRepresentativeForMenuItem(menuItem) else { return }
		
		if case let .Project(project) = item {
			let submenu = menuItem.submenu ?? {
				let submenu = NSMenu()
				menuItem.submenu = submenu
				return submenu
			}()
			
			let menuController = projectMenuControllerCache.objectForKey(project.UUID) as! LauncherProjectMenuController? ?? {
				let menuController = LauncherProjectMenuController(menu: submenu, project: project, projectManager: projectManager, navigator: navigator)
				projectMenuControllerCache.setObject(menuController, forKey: project.UUID)
				return menuController
			}()
			
			menuController.update()
		}
	}
}
