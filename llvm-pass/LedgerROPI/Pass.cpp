//===- Hello.cpp - Example code from "Writing an LLVM Pass" ---------------===//
//
// Part of the LLVM Project, under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//
//
// This file implements two versions of the LLVM "Hello World" pass described
// in docs/WritingAnLLVMPass.html
//
//===----------------------------------------------------------------------===//

#include "llvm/ADT/Statistic.h"
#include "llvm/IR/Function.h"
#include "llvm/Pass.h"
#include "llvm/Support/raw_ostream.h"

#include "llvm/IR/PassManager.h"
#include "llvm/IR/InstIterator.h"
#include "llvm/IR/Instructions.h"
#include "llvm/IR/InstrTypes.h"
#include "llvm/IR/Type.h"
#include <iostream>
using namespace llvm;

#define DEBUG_TYPE "LedgerROPI"

STATISTIC(LedgerROPICounter, "Applies ledger-specific relocations");

namespace {

	//Instruction* fixPointer(Instruction* L, Value* ptr, Function &F) {
	Value* fixPointer(Instruction* L, Value* ptr, Function &F) {
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		auto *off_addr = F.getParent()->getNamedGlobal("ro_offset");
		//std::cerr << "ro_offset: " << off_addr << "\n";
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		auto *nvram = F.getParent()->getNamedGlobal("_nvram");
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		//std::cerr << "nvram: " << nvram << "\n";
		auto *ni = new PtrToIntInst(ptr, Type::getInt32Ty(F.getContext()));
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		ni->insertBefore(L);
		auto *nvri = new PtrToIntInst(ptr, Type::getInt32Ty(F.getContext()));
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		nvri->insertBefore(L);
		//std::cerr << "ptr: " << ptr << "\n";
		auto *is_reloc = CmpInst::Create(Instruction::ICmp, CmpInst::ICMP_UGE, ni, nvri);
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		is_reloc->insertBefore(L);
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		auto *off = new LoadInst(Type::getInt32Ty(F.getContext()), off_addr, "", L);
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		auto *offed = BinaryOperator::Create(Instruction::Add, off, ni);
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		offed->insertBefore(L);
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		auto *backconvert = new IntToPtrInst(offed, ptr->getType());
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		backconvert->insertBefore(L);
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		auto *newaddr = SelectInst::Create(is_reloc, ptr, backconvert);
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		newaddr->insertBefore(L);
		//std::cerr << "Modifying pointer line: " << __LINE__ << "\n";
		// auto *newaddr = ptr;
		return newaddr;
	}

  struct LedgerROPI : public ModulePass {
    static char ID; // Pass identification, replacement for typeid
    LedgerROPI() : ModulePass(ID) {}

    bool runOnModule(Module &M) override {
	    M.getOrInsertGlobal("ro_offset",Type::getInt32Ty(M.getContext()));
	    M.getOrInsertGlobal("_nvram",Type::getInt32Ty(M.getContext()));
	    for (auto &F: M.getFunctionList())
      for ( auto I = inst_begin(F), E = inst_end(F); I != E; ++I ) {
	Instruction *inst = &*I;
	//std::cerr << "opcode" << inst->getOpcode() << "\n";
	switch( inst->getOpcode() ) {
	  case Instruction::Load: 
	    {
	      auto *L = dyn_cast<LoadInst>(inst);
	      //std::cerr << "Load fix for " ;
	      //std::cerr << "(" << inst->getOpcode() << ", " << Instruction::Load << ") ";
	      //errs() << *inst << "\n";
	      auto *newaddr = fixPointer(L, L->getPointerOperand(), F);
	      L->setOperand(L->getPointerOperandIndex(), newaddr);
	      break;
	    }
	  case Instruction::Invoke:
	    {
	      break;
	    }
	  case Instruction::Call:
	    {
	      auto *C = dyn_cast<CallInst>(inst);
	      //std::cerr << "Function call fix\n";
	      //auto *newaddr = fixPointer(C, C->getCalledOperand(), F);
	      //C->setCalledOperand(newaddr);
	      break;
	    }
	  default: break;
	}
      }
      return true;
    }
  };
}

char LedgerROPI::ID = 0;
static RegisterPass<LedgerROPI> X("ledger-ropi", "Ledger-specific read-only position-independent pass");

/*namespace llvm {
INITIALIZE_PASS(LedgerROPI, "ledger-ropi",
                "Ledger ROPI pass", false, false)

// Public interface to the GlobalDCEPass.
ModulePass *llvm::createLedgerROPI() {
  return new LedgerROPI();
}
}*/
