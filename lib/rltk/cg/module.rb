# Author:		Chris Wailes <chris.wailes@gmail.com>
# Project: 	Ruby Language Toolkit
# Date:		2012/03/20
# Description:	This file defines the Module class.

############
# Requires #
############

# Ruby Language Toolkit
require 'rltk/cg/bindings'
require 'rltk/cg/context'

#######################
# Classes and Modules #
#######################

module RLTK::CG
	class Module
		include BindingClass
		
		def self.read_bitcode(overloaded)
			buffer = if overloaded.is_a?(MemoryBuffer) then overloaded else MemoryBuffer.new(overloaded) end
			
			mod_ptr = FFI::MemoryPointer.new(:pointer)
			msg_ptr = FFI::MemoryPointer.new(:pointer)
			
			status = Bindings.parse_bitcode(buffer, mod_ptr, msg_ptr)
			
			if status != 0
				raise msg_ptr.get_pointer(0).get_string(0)
			else
				Module.new(mod_ptr.get_pointer(0))
			end
		end
		
		def initialize(overloaded, context = nil, &block)
			@ptr =
			case overloaded
			when FFI::Pointer
				overloaded
				
			when String
				if context
					Bindings.module_create_with_name_in_context(overloaded, check_type(context, Context, 'context'))
				else
					Bindings.module_create_with_name(overloaded)
				end
			end
			
			self.instance_exec(&block) if block
		end
		
		def context
			Context.new(Bindings.get_module_context(@ptr))
		end
		
		def dispose
			if @ptr
				Bindings.dispose_module(@ptr)
				
				@ptr = nil
			end
		end
		
		def dump
			Bindings.dump_module(@ptr)
		end
		
		def functions
			@functions ||= FunctionCollection.new(self)
		end
		alias :funs :functions
		
		def globals
			@globals ||= GlobalCollection.new(self)
		end
		
		def write_bitcode(overloaded)
			0 ==
			if overloaded.respond_to?(:path)
				Bindings.write_bitcode_to_file(@ptr, overloaded.path)
				
			elsif overloaded.respond_to?(:fileno)
				Bindings.write_bitcode_to_fd(@ptr, overloaded.fileno, 0, 1)
				
			elsif overloaded.is_a?(Integer)
				Bindings.write_bitcode_to_fd(@ptr, overloaded, 0, 1)
				
			elsif overloaded.is_a?(String)
				Bindings.write_bitcode_to_file(@ptr, overloaded)
			end
		end
		
		def verify
			do_verification(:return_status)
		end
		
		def verify!
			do_verification(:abort_process)
		end
		
		def do_verification(action)
			str_ptr	= FFI::MemoryPointer.new(:pointer)
			status	= Bindings.verify_module(@ptr, action, str_ptr)
			
			returning(status == 1 ? str_ptr.read_string : nil) { Bindings.dispose_message(str_ptr.read_pointer) }
		end
		private :do_verification
		
		class FunctionCollection
			include Enumerable
			
			def initialize(mod)
				@module = mod
			end
			
			def [](key)
				case key
				when String, Symbol
					self.named(key)
					
				when Integer
					(1...key).inject(self.first) { |fun| if fun then self.next(fun) else break end }
				end
			end
			
			def add(name, *type_info, &block)
				Function.new(@module, name, *type_info, &block)
			end
			
			def delete(fun)
				Bindings.delete_function(fun)
			end
			
			def each
				return to_enum(:each) unless block_given?
				
				fun = self.first
				
				while fun
					yield fun
					fun = self.next(fun)
				end
			end
			
			def first
				if (ptr = Bindings.get_first_function(@module)).null? then nil else Function.new(ptr) end
			end
			
			def last
				if (ptr = Bindings.get_last_function(@module)).null? then nil else Function.new(ptr) end
			end
			
			def named(name)
				if (ptr = Bindings.get_named_function(@module, name)).null? then nil else Function.new(ptr) end
			end
			
			def next(fun)
				if (ptr = Bindings.get_next_function(fun)).null? then nil else Function.new(ptr) end
			end
			
			def previous(fun)
				if (ptr = Bindings.get_previous_function(fun)).null? then nil else Function.new(ptr) end
			end
		end
		
		class GlobalCollection
			include Enumerable
			
			def initialize(mod)
				@module = mod
			end
			
			def [](key)
				case key
				when String, Symbol
					self.named(key)
					
				when Integer
					(1...key).inject(self.first) { |global| if global then self.next(global) else break end }
				end
			end
			
			def add(type, name)
				GlobalVariable.new(Bindings.add_global(@module, type, name))
			end
			
			def delete(global)
				Bindings.delete_global(global)
			end
			
			def each
				return to_enum(:each) unless block_given?
				
				global = self.first
				
				while global
					yield global
					global = self.next(global)
				end
			end
			
			def first
				if (ptr = Bindings.get_first_global(@module)).null? then nil else GlobalValue.new(ptr) end
			end
			
			def last
				if (ptr = Bindings.get_last_global(@module)).null? then nil else GlobalValue.new(ptr) end
			end
			
			def named(name)
				if (ptr = Bindings.get_named_global(@module, name)).null? then nil else GlobalValue.new(ptr) end
			end
			
			def next(global)
				if (ptr = Bindings.get_next_global(global)).null? then nil else GlobalValue.new(ptr) end
			end
			
			def previous(global)
				if (ptr = Bindings.get_previous_global(global)).null? then nil else GlobalValue.new(ptr) end
			end
		end
	end
end