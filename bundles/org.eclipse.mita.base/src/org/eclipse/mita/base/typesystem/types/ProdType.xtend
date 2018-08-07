package org.eclipse.mita.base.typesystem.types

import java.util.List
import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtend.lib.annotations.FinalFieldsConstructor

import static extension org.eclipse.mita.base.util.BaseUtils.force;

@EqualsHashCode
@Accessors
class ProdType extends TypeConstructorType {	
	protected final List<AbstractType> types;
		
	new(EObject origin, String name, AbstractType superType, List<AbstractType> types) {
		super(origin, name, superType);
		this.types = types;
		if(types.contains(null)){
			println("!NULL!");
		}
	}
	
	override toString() {
		"(" + types.join(", ") + ")"
	}
	
	override replace(TypeVariable from, AbstractType with) {
		new ProdType(origin, name, superType, types.map[ it.replace(from, with) ].force);
	}
	
	override getFreeVars() {
		return types.filter(TypeVariable);
	}
	
	override getTypeArguments() {
		return types;
	}
	
	

	override getVariance(int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		return new SubtypeConstraint(tau, sigma);
	}
	
	override void expand(Substitution s, TypeVariable tv) {
		val newTypeVars = types.map[ new TypeVariable(it.origin) as AbstractType ].force;
		val newPType = new ProdType(origin, name, superType, newTypeVars);
		s.add(tv, newPType);
	}
	
}