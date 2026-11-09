require 'rails_helper'
require 'open3'
require 'pty'
require 'timeout'
require 'tmpdir'

RSpec.describe Authentication::PasswordConsole do
  let(:password) { 'Synthetic protected terminal password' }
  let(:command_root) { Pathname.new(Dir.mktmpdir('seedbench-password-command-')) }
  let(:command_environment) do
    { 'SEEDBENCH_STATE_ROOT' => command_root.to_s, 'RAILS_LOG_LEVEL' => 'error', 'ANNOTATERB_SKIP_ON_DB_TASKS' => '1' }
  end

  before do
    output, status = Open3.capture2e(command_environment, RbConfig.ruby, 'bin/rails', 'db:prepare')
    raise "Disposable password database preparation failed: #{output}" unless status.success?
  end

  after { FileUtils.remove_entry_secure(command_root) }

  def wait_for_prompt(reader, output, prompt)
    Timeout.timeout(10) { output << reader.readpartial(1024) until output.b.include?(prompt.b) }
    true
  rescue EOFError, Errno::EIO
    false
  end

  def run_password_command
    output = +''
    status = nil
    PTY.spawn(command_environment, RbConfig.ruby, 'bin/rails', 'runner', 'script/operator_password.rb') do |reader, writer, pid|
      begin
        yield reader, writer, pid, output if wait_for_prompt(reader, output, 'Nouveau mot de passe')
        wait_for_prompt(reader, output, 'Mot de passe enregistré')
        _, status = Process.wait2(pid)
      ensure
        unless status
          Process.kill('TERM', pid)
          Process.wait(pid)
        end
      end
    end
    [ status, output.force_encoding(Encoding::UTF_8) ]
  end

  def stored_value(sql)
    SQLite3::Database.open(command_root.join('test.sqlite3').to_s) { |database| database.get_first_value(sql) }
  end

  it 'survives asynchronous I/O signals during entry and confirmation without echoing the password' do
    status, output = run_password_command do |reader, writer, pid, transcript|
      Process.kill('IO', pid)
      writer.puts(password)
      if wait_for_prompt(reader, transcript, 'Confirmez le mot de passe')
        Process.kill('IO', pid)
        writer.puts(password)
      end
    end

    expect(status).to be_success
    expect(output).to include('Mot de passe enregistré')
    expect(output).not_to include(password)
    expect(Devise::Encryptor.compare(Operator, stored_value('SELECT encrypted_password FROM operators WHERE id = 1'), password)).to be(true)
  end

  it 'still lets Ctrl C cancel entry without initializing the operator' do
    status, output = run_password_command { |_reader, writer, _pid, _transcript| writer.write("\u0003") }

    expect(status.exitstatus).to eq(1)
    expect(output).to include('Saisie interrompue')
    expect(output).not_to include('Mot de passe enregistré')
    expect(stored_value('SELECT COUNT(*) FROM operators')).to eq(0)
  end
end
