package org.eclipse.mita.base.typesystem;

import org.eclipse.emf.ecore.EObject;
import org.eclipse.mita.base.typesystem.solver.SymbolTable;

public interface ISymbolFactory {
	public SymbolTable create(EObject obj);
}
