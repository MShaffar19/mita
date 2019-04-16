/********************************************************************************
 * Copyright (c) 2018, 2019 Robert Bosch GmbH & TypeFox GmbH
 *
 * This program and the accompanying materials are made available under the
 * terms of the Eclipse Public License 2.0 which is available at
 * http://www.eclipse.org/legal/epl-2.0.
 *
 * Contributors:
 *    Robert Bosch GmbH & TypeFox GmbH - initial contribution
 *
 * SPDX-License-Identifier: EPL-2.0
 ********************************************************************************/

package org.eclipse.mita.base.typesystem.solver

import com.google.inject.Inject
import com.google.inject.Provider
import it.unimi.dsi.fastutil.ints.Int2ObjectMap
import it.unimi.dsi.fastutil.ints.Int2ObjectMaps
import it.unimi.dsi.fastutil.ints.Int2ObjectOpenHashMap
import java.util.Map
import java.util.function.Predicate
import org.eclipse.mita.base.typesystem.types.AbstractType
import org.eclipse.mita.base.typesystem.types.TypeVariable
import org.eclipse.mita.base.util.DebugTimer
import org.eclipse.xtend.lib.annotations.Accessors

import static extension org.eclipse.mita.base.util.BaseUtils.force

class Substitution {
	@Inject protected Provider<ConstraintSystem> constraintSystemProvider;
	@Accessors
	protected Int2ObjectMap<AbstractType> content = new Int2ObjectOpenHashMap();
	protected Int2ObjectMap<TypeVariable> idxToTypeVariable = new Int2ObjectOpenHashMap();
	
	def Substitution filter(Predicate<TypeVariable> predicate) {
		val result = new Substitution;
		result.constraintSystemProvider = constraintSystemProvider;
		
		result.content.putAll(content.filter[idx, __| predicate.test(idxToTypeVariable.get(idx.intValue)) ])
		result.idxToTypeVariable.putAll(idxToTypeVariable.filter[idx, __| predicate.test(idxToTypeVariable.get(idx.intValue)) ])
		
		return result;
	}
	
	protected def checkDuplicate(TypeVariable key, Provider<AbstractType> type) {
		val prevType = content.get(key.idx);
		if(prevType !== null) {
			val newType = type.get;
			if(prevType != newType) {
				print("")
			}

			println('''overriding «key» ≔ «prevType» with «newType»''')
		}
	}
	
	def void add(TypeVariable variable, AbstractType type) {
		if(variable === null || type === null) {
			throw new NullPointerException;
		}
		add(#[variable->type]);
	}
	
	def void add(Map<TypeVariable, AbstractType> content) {
		val newContent = new Substitution();
		content.forEach[tv, typ|
			newContent.content.put(tv.idx, typ);
			newContent.idxToTypeVariable.put(tv.idx, tv);
		]
		val resultSub = newContent.apply(this);
		this.content = resultSub.content;
		this.idxToTypeVariable = resultSub.idxToTypeVariable;
	}
	def void add(Iterable<Pair<TypeVariable, AbstractType>> content) {
		add(content.toMap([it.key], [it.value]))
	}
	
	def Substitution replace(TypeVariable from, AbstractType with) {
		val result = new Substitution();
		result.constraintSystemProvider = constraintSystemProvider;
		result.content = new Int2ObjectOpenHashMap(content.mapValues[it.replace(from, with)])
		// nothing changes for typevariable idx
		return result;
	}
	
	def AbstractType apply(TypeVariable typeVar) {
		var AbstractType result = typeVar;
		var nextResult = content.get(typeVar.idx); 
		while(nextResult !== null && result != nextResult && !result.freeVars.empty) {
			result = nextResult;
			nextResult = applyToType(result);
		}
		return result;
	}
		
	def Substitution apply(Substitution oldEntries) {
		val result = new Substitution();
		val newEntries = this;
		result.constraintSystemProvider = newEntries.constraintSystemProvider ?: oldEntries.constraintSystemProvider;
		result.content = new Int2ObjectOpenHashMap(oldEntries.content);
		for(int k: result.content.keySet.force) {
			val vOld = result.content.get(k);
			val vNew = vOld.replace(newEntries);
			if(vOld !== vNew) {	
				result.content.put(k, vNew);	
			}
		}
		result.content.putAll(newEntries.content);
		result.idxToTypeVariable = new Int2ObjectOpenHashMap(oldEntries.idxToTypeVariable);
		result.idxToTypeVariable.putAll(newEntries.idxToTypeVariable);
		return result;
	}
	
	// returns the mutated argument (or a copy of this if other is an empty substitution)
	def Substitution applyMutating(Substitution oldEntries) {
		if(oldEntries == EMPTY) {
			return apply(oldEntries);
		}
		val result = oldEntries;
		val newEntries = this;
		result.constraintSystemProvider = newEntries.constraintSystemProvider ?: oldEntries.constraintSystemProvider;
		for(int k: result.content.keySet) {
			val vOld = result.content.get(k);
			val vNew = vOld.replace(newEntries);
			if(vOld !== vNew) {	
				result.content.put(k, vNew);	
			}
		}
		result.content.putAll(newEntries.content);
		result.idxToTypeVariable.putAll(newEntries.idxToTypeVariable);
		return result;
	}
	
	def AbstractType applyToType(AbstractType typ) {
		typ.replace(this);
	}
	def Iterable<AbstractType> applyToTypes(Iterable<AbstractType> types) {
		return types.map[applyToType];
	}
	
	def apply(ConstraintSystem system) {
		return applyToNonAtomics(applyToAtomics(applyToGraph(system)));
	}
	
	def applyToGraph(ConstraintSystem system) {
		return applyToGraph(system, new DebugTimer(true));
	}
	def applyToGraph(ConstraintSystem system, DebugTimer debugTimer) {
		debugTimer.start("typeClasses")
		system.typeClasses.replaceAll[qn, tc | 
			tc.replace(this)
		];
		debugTimer.stop("typeClasses")
		
		// to keep overridden methods etc. we clone instead of using a copy constructor
		debugTimer.start("explicitSubtypeRelations");
//		system.explicitSubtypeRelations.nodeIndex.replaceAll[i, t | t.replace(this)];
//		system.explicitSubtypeRelations.computeReverseMap;
		system.explicitSubtypeRelationsTypeSource.replaceAll[tname, t | t.replace(this)];
		debugTimer.stop("explicitSubtypeRelations");
		
		return system;
	}
	
	def ConstraintSystem applyToAtomics(ConstraintSystem system) {
		applyToAtomics(system, new DebugTimer(true));
	}
	def ConstraintSystem applyToAtomics(ConstraintSystem system, DebugTimer debugTimer) {
		debugTimer.start("constraints");
		// atomic constraints may become composite by substitution, the opposite can't happen
		val unknownConstrains = system.atomicConstraints.map[c | c.replace(this)].force;
		debugTimer.stop("constraints");
		system.atomicConstraints.clear();
		debugTimer.start("atomicity");
		for(it: unknownConstrains) {
			if(it.isAtomic(system)) {
				system.atomicConstraints.add(it);
			}
			else {
				system.nonAtomicConstraints.add(it);
			}
		}
		debugTimer.stop("atomicity");
		return system;
	}
	def ConstraintSystem applyToNonAtomics(ConstraintSystem system) {
		system.nonAtomicConstraints.replaceAll[it.replace(this)];
		return system;
	}
	
	def Iterable<Pair<TypeVariable, AbstractType>> getSubstitutions() {
		return content.int2ObjectEntrySet.map[idxToTypeVariable.get(it.intKey) -> it.value];
	}
	
	public static final Substitution EMPTY = new Substitution() {
		
		override apply(Substitution to) {
			return to;
		}
				
		override applyMutating(Substitution oldEntries) {
			return oldEntries
		}
				
		override getContent() {
			return Int2ObjectMaps.unmodifiable(super.getContent());
		}
		override replace(TypeVariable from, AbstractType with) {
			return new Substitution() => [add(from, with)]
		}		
		override add(Iterable<Pair<TypeVariable, AbstractType>> content) {
			throw new UnsupportedOperationException("Cannot add to empty substitution");
		}
		override add(TypeVariable variable, AbstractType type) {
			throw new UnsupportedOperationException("Cannot add to empty substitution");
		}
		override add(Map<TypeVariable, AbstractType> content) {
			throw new UnsupportedOperationException("Cannot add to empty substitution");
		}
		override setContent(Int2ObjectMap<AbstractType> content) {
			throw new UnsupportedOperationException("Cannot add to empty substitution");
		}
	}
	
	override toString() {
		val sep = '\n'
		return content.int2ObjectEntrySet.map[ '''«it.intKey» ≔ «it.value»''' ].join(sep);
	}
	
}