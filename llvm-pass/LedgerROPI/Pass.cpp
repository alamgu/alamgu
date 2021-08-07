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
#include "llvm/IR/InlineAsm.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/IR/Type.h"
#include <iostream>
using namespace llvm;

#define DEBUG_TYPE "LedgerROPI"

STATISTIC(LedgerROPICounter, "Applies ledger-specific relocations");

namespace {

  Value* fixPointer(Instruction* L, Value* ptr, Function &F, Module &M) {
    IRBuilder<> builder(L);
    auto vpt = Type::getInt8Ty(F.getContext())->getPointerTo();

    auto *castArgument = builder.CreatePointerCast(ptr, vpt, "as_void");
    FunctionCallee pic_fn = M.getOrInsertFunction("pic", vpt, vpt);
    std::vector<Value*> args(1,castArgument);
    auto *fixed_ptr = builder.CreateCall(pic_fn.getFunctionType(), pic_fn.getCallee(), args, "call_pic");
    return builder.CreatePointerCast(fixed_ptr, ptr->getType(), "fixed_ptr");
  }

  struct LedgerROPI : public ModulePass {
    static char ID;
    LedgerROPI() : ModulePass(ID) {}

    bool runOnModule(Module &M) override {
      M.getOrInsertGlobal("ro_offset",Type::getInt32Ty(M.getContext()));
      M.getOrInsertGlobal("_nvram",Type::getInt32Ty(M.getContext()));
      for (auto &F: M.getFunctionList())
        for ( auto I = inst_begin(F), E = inst_end(F); I != E; ++I ) {
          Instruction *inst = &*I;
          switch( inst->getOpcode() ) {
            case Instruction::Load: 
              {
                auto *L = dyn_cast<LoadInst>(inst);
                auto *P = L->getPointerOperand();
                if(isa<AllocaInst>(P)) break;
                auto *newaddr = fixPointer(L, L->getPointerOperand(), F, M);
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
                auto *targ = C->getCalledOperand();
                auto *targF = dyn_cast<Function>(targ);
                // Don't change normal function references (handled by the pic code
                // already) or inline assembly.  Ignoring intrinsic functions and
                // inline assembly is required here - they don't have pointers - but
                // ignoring direct function references is not and is here as an
                // approximation of "is an indirect function reference".
                if(targ && ! targF && ! isa<InlineAsm>(targ)) {
                  auto *newaddr = fixPointer(C, targ, F, M);
                  C->setCalledOperand(newaddr);
                }
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

