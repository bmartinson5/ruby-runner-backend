require 'timeout'

class ContentsController < ApplicationController
  def index
    json_response("server has responded")
  end

  def create
    content = Content.create!(content_params)
    json_response(content)
  end

  def show
    content = Content.create!(content_params)
    json_response(content)
  end

  def find_problem
    content = Content.where(problem_index: params[:problem_index])
    json_response(content)
  end

  def create_tests(function_name, initial_code, problem_index)
    test_params = [
        ["[3, 3, 1], 6", "[-4, 6, -8, 1], -3", "[-3, -2, -1, -9], -10"],
        ["\"tower\"", "\"hannah\"", "\"A man, a plan, a canal: Panama\"" ],
        ["\"eroh\", \"hero\"", "\"HleOl\", \"HellO\"", "\"not\", \"aword\""],
        ["[1,2,3]", "[1, 8, 6, 4]", "[-1, -2, -3]"]
      ]

    tests = []
    test_params[problem_index].each do |param|
      test = initial_code.dup
      test << "print "
      test << function_name
      test << "("
      test << param
      test << ")"
      test << "\n"
      tests.push(test)
    end
    return tests

  end


  def run_tests(tests)
    test_output = []
    tests.each_with_index do |test, index|
      $stdout = File.new("test#{index+1}.out", 'w')
      $stdout.sync = true

      proc = Proc.new do
        $SAFE = 1
        begin
          Timeout::timeout(1) do
            eval(test)
          end
        rescue Exception => e
          puts 'Error: ' << e.to_s
        end
      end
      proc.call
      test_output.push(File.read("test#{index+1}.out"))
    end
    test_output.each_with_index do |output, index|
      test_output[index] = output.gsub(/\n/, '')
    end
    test_output
  end

  def check_unpermitted_objects(code)
    return code.match(/^\s*(File|Dir|stdout|ARGV|IO|require|include)(\.|\s|$|\()/)
  end

  def check_unpermitted_functions(code)
      functions_defined = find_defined_functions(code)
      functions_permitted = Content.permitted_misc_functions + Content.permitted_arr_functions +
                            Content.permitted_str_functions + Content.permitted_object_functions + functions_defined
      functions_called = find_called_functions(code)
      functions_called.each do |function_name|
        if !(functions_permitted.include? function_name)
          return function_name
        end
      end
      false
  end

  def find_defined_functions(code)
    code.scan(/def (([a-z]|\_)+)/).map { |name| name[0]}
  end

  def find_called_functions(code)
    methods = code.scan(/[a-z]+\.(([a-z]|[A-Z]|\_)+)/).map { |name| name[0]}
    functions = code.scan(/(([a-z]|[A-Z]|\_)+)\(/).map { |name| name[0]}
    return methods + functions
  end

  def run_code
    function_name = content_params[:function_name]
    code = ""
    blocks = content_params[:content]["blocks"]
    blocks.each do |block, index|
      code << block[:text]
      code << "\n"
    end

    unpermitted_object = check_unpermitted_objects(code)
    if unpermitted_object
      return json_response(["Unpermitted Object Reference: '#{unpermitted_object}'"])
    end
    
    old_stdout = $stdout.dup
    unpermitted_function = check_unpermitted_functions(code)
    if unpermitted_function
      return json_response(["Unpermitted or Undefined Function Call: '#{unpermitted_function}'"])
    end


    tests = create_tests(function_name, code, content_params[:problem_index].to_i)
    test_output = run_tests(tests)
    $stdout = old_stdout
    # json_response(code)
    json_response(test_output)
  end

  private
   def content_params
     params.permit(:function_name, :problem_index, content: [entityMap: {}, blocks: [:key, :text, :type, :depth, inlineStyleRanges: [], entityRanges: [], data: {}]])
   end

end
