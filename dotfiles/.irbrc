require "amazing_print"

AmazingPrint.irb!
IRB.conf[:USE_MULTILINE] = false
IRB.conf[:USE_AUTOCOMPLETE] = false

def time(&)
  time = Time.now
  yield if block_given?
  puts "Took #{Time.now - time}s"
end
