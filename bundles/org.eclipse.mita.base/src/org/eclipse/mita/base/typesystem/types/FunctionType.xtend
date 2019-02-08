package org.eclipse.mita.base.typesystem.types

import org.eclipse.emf.ecore.EObject
import org.eclipse.mita.base.types.validation.IValidationIssueAcceptor.ValidationIssue
import org.eclipse.mita.base.typesystem.constraints.SubtypeConstraint
import org.eclipse.mita.base.typesystem.infra.TypeClassUnifier
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.solver.Substitution
import org.eclipse.xtend.lib.annotations.Accessors
import org.eclipse.xtend.lib.annotations.EqualsHashCode
import org.eclipse.xtext.diagnostics.Severity

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.zip
import org.eclipse.mita.base.typesystem.infra.Tree

@EqualsHashCode
@Accessors
class FunctionType extends TypeConstructorType {
	static def unify(ConstraintSystem system, Iterable<AbstractType> instances) {
		return new FunctionType(null, TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, instances.map[it as TypeConstructorType].map[it.type]),
			TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, instances.map[it as FunctionType].map[it.from]),
			TypeClassUnifier.INSTANCE.unifyTypeClassInstancesStructure(system, instances.map[it as FunctionType].map[it.to])
		)
	}
			
	new(EObject origin, AbstractType type, AbstractType from, AbstractType to) {
		this(origin, type, #[from, to]);
		
//		if(from === null || to === null) {
//			throw new NullPointerException;
//		}
	}
	
	new(EObject origin, AbstractType type, Iterable<AbstractType> typeArgs) {
		super(origin, type, typeArgs);
	}
	
	def AbstractType getFrom() {
		return typeArguments.get(0);
	}
	def AbstractType getTo() {
		return typeArguments.get(1);
	}
	
	override toString() {
		from + " → " + to
	}
	
	override getTypeArguments() {
		return #[from, to];
	}
	
	override getVariance(ValidationIssue issue, int typeArgumentIdx, AbstractType tau, AbstractType sigma) {
		if(typeArgumentIdx == 1) {
			return new SubtypeConstraint(tau, sigma, new ValidationIssue(issue, '''Incompatible types: %1$s is not subtype of %2$s.'''));
		}
		else {
			// function arguments are contravariant
			return new SubtypeConstraint(sigma, tau, new ValidationIssue(issue, '''Incompatible types: %1$s is not subtype of %2$s.'''));
		}
	}
	
	override expand(ConstraintSystem system, Substitution s, TypeVariable tv) {
		val newFType = new FunctionType(origin, type, system.newTypeVariable(from.origin), system.newTypeVariable(to.origin));
		s.add(tv, newFType);
	}
	
	override toGraphviz() {
		'''"«to»" -> "«this»"; "«this»" -> "«from»"; «to.toGraphviz» «from.toGraphviz»''';
	}
	

	override unquote(Iterable<Tree<AbstractType>> children) {
		return new FunctionType(origin, children.head.node.unquote(children.head.children), children.tail.map[it.node.unquote(it.children)].force);
	}
	
	override map((AbstractType)=>AbstractType f) {
		val newTypeArgs = typeArguments.map[ it.map(f) ].force;
		val newType = type.map(f);
		if(type !== newType || typeArguments.zip(newTypeArgs).exists[it.key !== it.value]) {
			return new FunctionType(origin, newType, newTypeArgs);
		}
		return this;
	}
	
}