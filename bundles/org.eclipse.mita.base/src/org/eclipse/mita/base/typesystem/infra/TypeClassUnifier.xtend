package org.eclipse.mita.base.typesystem.infra

import java.util.Set
import java.util.TreeSet
import org.eclipse.mita.base.typesystem.solver.ConstraintSystem
import org.eclipse.mita.base.typesystem.types.AbstractBaseType
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.FunctionType
import org.eclipse.mita.base.typesystem.types.ProdType
import org.eclipse.mita.base.typesystem.types.SumType
import org.eclipse.mita.base.typesystem.types.TypeConstructorType
import org.eclipse.mita.base.typesystem.types.TypeScheme
import org.eclipse.mita.base.typesystem.types.TypeVariable

import static extension org.eclipse.mita.base.util.BaseUtils.force
import static extension org.eclipse.mita.base.util.BaseUtils.transpose
import static extension org.eclipse.mita.base.util.BaseUtils.zip
import java.util.Comparator
import com.google.common.collect.Comparators

class TypeClassUnifier {
	public static val TypeClassUnifier INSTANCE = new TypeClassUnifier();
	
	val ClassTree<AbstractType> typeHierarchy;
	val Iterable<Class<? extends AbstractType>> typeOrder;
	
	protected new() {
		typeHierarchy = #[AbstractBaseType, /* AbstractType,*/ /*AtomicType, BaseKind, BottomType, FloatingType,*/ FunctionType, /*IntegerType, NumericType,*/ ProdType, SumType, TypeConstructorType, /*TypeHole, TypeScheme,*/ TypeVariable/*, UnorderedArguments*/]
			.fold(new ClassTree<AbstractType>(AbstractType), [t, c |
				t.add(c);
			])
		
		typeOrder = typeHierarchy.postOrderTraversal;
	}
	
//	fst :: (String, i32) -> String
//	fst :: (i8, i32) -> i8
	def TypeClass unifyTypeClassInstancesStructure(ConstraintSystem system, TypeClass typeClass) {
		val types = typeClass.instances.keySet;
		if(types.exists[!(it instanceof TypeScheme)] && types.size > 1) {
			return typeClass;
		}
		if(types.size == 1) {
			val resultType = if(types.head instanceof TypeScheme) {
				types.head
			} else {
				new TypeScheme(null, #[], types.head)
			}
			return new TypeClass(typeClass.instances, resultType)
		}
		val instances = types.map[
			if(it instanceof TypeScheme) {
				it.instantiate(system).value;	
			}
		].force;
		// commonStructure: fst :: (a, b) -> c
		val commonStructure = unifyTypeClassInstancesStructure(system, instances);
		val commonType = unifyTypeClassInstancesTypes(system, commonStructure, instances);
		val typeSchemes = types.filter(TypeScheme);
		val paths = typeSchemes.flatMap[it.vars.map[v | 
			new TreeSet<Iterable<Integer>>(Comparators.lexicographical(Comparator.naturalOrder)) => [ts |
				ts.addAll(it.on.quote.findAll(v) );	
			];
		]];
		val commonPaths = paths.tail.fold(paths.head, [s1, s2 | 
			val intersection = new TreeSet<Iterable<Integer>>(Comparators.lexicographical(Comparator.naturalOrder));
			intersection.addAll(s1);
			intersection.retainAll(s2);
			return intersection as Set<Iterable<Integer>>;
		]);
		return new TypeClass(typeClass.instances, new TypeScheme(null, commonPaths.map[commonType.get(it) as TypeVariable].toSet.force, commonType.node.unquote(commonType.children)));
	}
	
	def Tree<AbstractType> unifyTypeClassInstancesTypes(ConstraintSystem system, AbstractType commonTypeStructure, Iterable<AbstractType> instances) {
		// find out that fst :: (a, i32) -> c
		val structure = commonTypeStructure.quote();
		val quotedInstances = instances.map[quoteLike(structure)].force;
		
//		val commonTypesAcross = unifyTypeClassInstancesWithCommonTypesAcross(structure, quotedInstances);
		val commonTypeQuoted = unifyTypeClassInstancesWithReusedTypes(structure, quotedInstances);
		return commonTypeQuoted;
	}
	
	def Tree<AbstractType> unifyTypeClassInstancesWithCommonTypesAcross(Tree<AbstractType> commonTypeStructure, Iterable<Tree<AbstractType>> instances) {
		val result = new Tree(
			if(instances.map[it.node].groupBy[it].size == 1) {
				instances.head.node
			}
			else {				
				commonTypeStructure.node	
			}
		);
		
		result.children += commonTypeStructure.children.zip(instances.map[it.children].transpose).map[unifyTypeClassInstancesWithCommonTypesAcross(it.key, it.value)]
		return result;
	}
	
	def Tree<AbstractType> unifyTypeClassInstancesWithReusedTypes(Tree<AbstractType> _commonTypeStructure, Iterable<Tree<AbstractType>> instances) {
		val commonTypeStructure = Tree.copy(_commonTypeStructure);
		val freeVarsAndPaths = commonTypeStructure.toPathIterable.filter[it.value instanceof TypeVariable].force;
		while(!freeVarsAndPaths.empty) {
			// pop from free vars
			val pathAndVar = freeVarsAndPaths.head;
			freeVarsAndPaths.remove(0);
			
			val path = pathAndVar.key;
			val typeVar = pathAndVar.value;
			val instanceVars = instances.map[it.get(path)].force;
			// a list of lists of paths
			// for each instance, a list of paths to locations of typeVar
			val Iterable<Iterable<Iterable<Integer>>> reusedLocations = instances.zip(instanceVars).map[it.key.findAll(it.value)];
			// by making them sets we can merge them (conceptually) by intersecting
			val reusedLocationsMergable = reusedLocations.map[locs |
				new TreeSet<Iterable<Integer>>(Comparators.lexicographical(Comparator.naturalOrder)) => [
					addAll(locs);	
				];
			];
			val commonPaths = reusedLocationsMergable.tail.fold(reusedLocationsMergable.head, [s1, s2 | 
				val intersection = new TreeSet<Iterable<Integer>>(Comparators.lexicographical(Comparator.naturalOrder));
				intersection.addAll(s1);
				intersection.retainAll(s2);
				return intersection as Set<Iterable<Integer>>;
			]);
			commonPaths.forEach[ p |
				commonTypeStructure.set(p, typeVar);	
				freeVarsAndPaths.removeIf[Comparators.lexicographical(Comparator.naturalOrder).compare(it.key, p) == 0];
			]
			
		}
		return commonTypeStructure;
	}
	
	def AbstractType unifyTypeClassInstancesStructure(ConstraintSystem system, Iterable<AbstractType> _instances) {
		val instances = _instances.map[
			if(it instanceof TypeScheme) {
				it.instantiate(system).value;
			}
			else {
				it;
			}
		]
		
		val commonType = typeOrder.findFirst[typeClazz | 
			instances.forall[typeClazz.isAssignableFrom(it.getClass)]
		]
				
		val m = commonType.getMethod("unify", ConstraintSystem, Iterable);
		val result = m.invoke(null, system, instances);
		
		return result as AbstractType;
	}
		
}
