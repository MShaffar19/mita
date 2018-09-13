package org.eclipse.mita.base.typesystem.infra

import org.eclipse.core.resources.IFile
import org.eclipse.core.resources.IResource
import org.eclipse.core.resources.ResourcesPlugin
import org.eclipse.core.runtime.Path
import org.eclipse.emf.ecore.resource.ResourceSet
import org.eclipse.xtext.naming.QualifiedName
import org.eclipse.core.resources.IContainer
import org.eclipse.emf.common.util.URI

class DefaultPackageResourceMapper implements IPackageResourceMapper {
	
	override getResourceURIs(ResourceSet rs, QualifiedName packageName) {
		// TODO: optimize access across calls by caching result or previously building an index
		// TODO: look at libraries to find required resources
		if(rs instanceof MitaResourceSet) {
			if(rs.projectConfig.containsKey(packageName.toString)) {
				return rs.projectConfig.get("dependencies").get(packageName.toString).map[URI.createURI(it)]
			}
		}
		val platformString = rs.resources.head.getURI().toPlatformString(true);
		val myFile = ResourcesPlugin.getWorkspace().getRoot().getFile(new Path(platformString));
		return myFile.project.listAllFiles.filter[ it.name.endsWith(".mita") || it.name.endsWith(".platform") ].map[ URI.createPlatformResourceURI(it.fullPath.toString(), true) ];
	}
	
	protected def Iterable<IFile> listAllFiles(IResource resource) {
		if(resource instanceof IContainer) {
			return resource.members.flatMap[ it.listAllFiles ]
		} else if(resource instanceof IFile) {
			return #[ resource ];
		} else {
			return #[]
		}
	}
	
}