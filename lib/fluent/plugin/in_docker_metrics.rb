# -*- coding: iso-8859-1 -*-
module Fluent
  class DockerMetricsInput < Input
    Plugin.register_input('docker_metrics', self)

    config_param :cgroup_path, :string, :default => '/sys/fs/cgroup'
    config_param :stats_interval, :time, :default => 60 # every minute
    config_param :tag_prefix, :string, :default => "docker"
    config_param :docker_infos_path, :string, :default => '/var/lib/docker/execdriver/native'
    config_param :docker_network_stats, :string, :default => '/sys/class/net'
    config_param :docker_socket, :string, :default => 'unix:///var/run/docker.sock'

    # Class variables
    @@network_metrics = {
      'rx_bytes' => 'counter', 
      'tx_bytes' => 'counter',
      'tx_packets' => 'counter',
      'rx_packets' => 'counter',
      'tx_errors' => 'counter',
      'rx_errors' => 'counter'
    }

    #
    # memory: http://lxr.free-electrons.com/source/Documentation/cgroups/memory.txt
    # cpuacct: http://lxr.free-electrons.com/source/Documentation/cgroups/cpuacct.txt
    # blkio: http://lxr.free-electrons.com/source/Documentation/cgroups/blkio-controller.txt
    #
    @@docker_metrics = {
      'memory.stat' => { 
        'type' => 'memory',
        'parser' => 'KeyValueStatsParser',
        'counter' => {'default' => 'gauge','(total_)?pg.*' => 'counter'}
      },
      
      'cpuacct.stat' => { 
        'type' => 'cpuacct',
        'parser' => 'KeyValueStatsParser',
        'counter' => 'counter'
      },
      'cpuacct.usage' => {
        'type' => 'cpuacct',
        'parser' =>' SimpleValueParser',
        'counter' => 'counter'
      },
      'blkio.io_service_bytes' => {
        'type' => 'blkio',
        'parser' => 'BlkioStatsParser',
        'counter' => 'counter'
      },
      'blkio.io_queued_recursive' => {
        'type' => 'blkio',
        'parser' => 'KeyValueStatsParser',
        'counter' => 'counter'
      },
      'blkio.io_merged_recursive' => {
        'type' => 'blkio',
        'parser' => 'KeyValueStatsParser',
        'counter' => 'counter'
      },
      'blkio.io_wait_time_recursive' => {
        'type' => 'blkio',
        'parser' => 'BlkioStatsParser',
        'counter' => 'counter'
      },
      'blkio.io_service_time_recursive' => {
        'type' => 'blkio',
        'parser' => 'BlkioStatsParser',
        'counter' => 'counter'
      },
      'blkio.io_serviced_recursive' => {
        'type' => 'blkio',
        'parser' => 'BlkioStatsParser',
        'counter' => 'counter'
      },
      'blkio.io_service_bytes_recursive' => {
        'type' => 'blkio',
        'parser' => 'BlkioStatsParser',
        'counter' => 'counter'
      },
      'blkio.io_queued' => {
        'type' => 'blkio',
        'parser' => 'KeyValueStatsParser',
        'counter' => 'counter'
      },
      'blkio.io_merged' => {
        'type' => 'blkio',
        'parser' => 'KeyValueStatsParser',
        'counter' => 'counter'
      },
      'blkio.io_wait_time' => {
        'type' => 'blkio',
        'parser' => 'BlkioStatsParser',
        'counter' => 'counter'
      },
      'blkio.io_service_time' => {
        'type' => 'blkio',
        'parser' => 'BlkioStatsParser',
        'counter' => 'counter'
      },

      'blkio.io_serviced' => {
        'type' => 'blkio',
        'parser' => 'BlkioStatsParser',
        'counter' => 'counter'
      },
      'blkio.throttle.io_serviced' => {
        'type' => 'blkio',
        'parser' => 'BlkioStatsParser',
        'counter' => 'counter'
      },
      'blkio.throttle.io_service_bytes' => {
        'type' => 'blkio',
        'parser' => 'BlkioStatsParser',
        'counter' => 'counter'
      }
    }

    def initialize
      super
      require 'socket'
      @hostname = Socket.gethostname
      require 'json'
    end

    def configure(conf)
      super
    end

    def start
      @loop = Coolio::Loop.new
      tw = TimerWatcher.new(@stats_interval, true, @log, &method(:get_metrics))
      tw.attach(@loop)
      @thread = Thread.new(&method(:run))
    end
    def run
      @loop.run
    rescue
      log.error "unexpected error", :error=>$!.to_s
      log.error_backtrace
    end

    def get_interface_path(id)
      filename = "#{@docker_infos_path}/#{id}/state.json"
      raise ConfigError if not File.exists?(filename)
      
      # Read JSON from file
      json = File.read(filename)
      parsed = JSON.parse(json)

      keys = parsed.keys

      interface_name =  parsed["network_state"]["veth_host"]
      
      interface_statistics_path = "#{@docker_network_stats}/#{interface_name}/statistics"
      return interface_name, interface_statistics_path
    end

    # Metrics collection methods
    def get_metrics
      list_container_ids.each do |id|
        @@docker_metrics.each do |metric_name, metric_infos|
          emit_container_metric(id, metric_name, metric_infos) 
        end

        interface_name, interface_path = get_interface_path(id)
       
        @@network_metrics.each do |metric_name, metric_type|
          emit_container_network_metric(id, interface_name, interface_path, metric_name, metric_type)
        end
      end
      
    end

    def list_container_ids
      `docker -H #{@docker_socket} ps --no-trunc -q `.split /\s+/
    end
   
    def emit_container_network_metric(id, interface_name, path, metric_filename, metric_type)
      filename = "#{path}/#{metric_filename}"
      raise ConfigError if not File.exists?(filename)

      data = {}

      time = Engine.now
      mes = MultiEventStream.new

      value = File.read(filename)
      data[:key] = metric_filename
      data[:value] = value.to_i
      data[:type] = metric_type
      data[:if_name] = interface_name
      data[:td_agent_hostname] = "#{@hostname}"
      data[:source] = "#{id}"
      mes.add(time, data)

      tag = "#{@tag_prefix}.network.stat"
      Engine.emit_stream(tag, mes)
    end

    def emit_container_metric(id, metric_filename, metric_infos, opts = {})
      path = "#{@cgroup_path}/#{metric_infos['type']}/docker/#{id}/#{metric_filename}"
      if File.exists?(path)
        parser = case metric_infos['parser']
                 when 'BlkioStatsParser'
                   BlkioStatsParser.new(path, metric_filename.gsub('.', '_'))
                 when 'KeyValueStatsParser'
                   KeyValueStatsParser.new(path, metric_filename.gsub('.', '_'))
                 else
                   SimpleValueParser.new(path, metric_filename.gsub('.', '_'))
                 end
        time = Engine.now
        tag = "#{@tag_prefix}.#{metric_filename}"
        mes = MultiEventStream.new
        parser.parse_each_line do |data|
          next if not data
	  if metric_infos['counter'].class == Hash
            found = 0
	    defaulttype = metric_infos['counter']['default']
            choices = metric_infos['counter'].select { |key, value| !key.to_s.match(/^default$/) }
            choices.each do |regex, countertype|
              if data[:key].match(/#{regex}/)
                found = 1
                data['type'] = countertype
                break
              end
            end
            if found == 0
	      data['type'] = defaulttype
	    end
          else
            data['type'] = metric_infos['counter']
          end
          data[:td_agent_hostname] = "#{@hostname}"
          data[:source] = "#{id}"
          mes.add(time, data)
        end
        Engine.emit_stream(tag, mes)
      else
        nil
      end
    end

    def shutdown
      @loop.stop
      @thread.join
    end

    class TimerWatcher < Coolio::TimerWatcher

      def initialize(interval, repeat, log, &callback)
        @callback = callback
        @log = log
        super(interval, repeat)
      end
      def on_timer
        @callback.call
      rescue
        @log.error $!.to_s
        @log.error_backtrace
      end
    end

    class CGroupStatsParser
      def initialize(path, metric_type)
        raise ConfigError if not File.exists?(path)
        @path = path
        @metric_type = metric_type
      end

      def parse_line(line)
      end

      def parse_each_line(&block)
        File.new(@path).each_line do |line|
          block.call(parse_line(line))
        end
      end
    end

    class SimpleValueParser < CGroupStatsParser
      def parse_line(line)
        metric_name = @metric_type.split('_')[1]
        { key: metric_name.downcase, value: line.to_i }
      end
    end

    class KeyValueStatsParser < CGroupStatsParser
      def parse_line(line)
        k, v = line.split(/\s+/, 2)
        if k and v
          { key: k.downcase, value: v.to_i }
        else
          nil
        end
      end
    end

    class BlkioStatsParser < CGroupStatsParser
      TotalLineRegExp = /^Total (?<value>\d+)/
      BlkioLineRegexp = /^(?<major>\d+):(?<minor>\d+) (?<key>[^ ]+) (?<value>\d+)/
      
      def parse_line(line)
        m = TotalLineRegExp.match(line)
        if m
          { key: 'total', value: m['value']}
        else
          m = BlkioLineRegexp.match(line)
          if m
            { key: m["key"].downcase, value: m["value"] , device: m['major'] + ':' + m['minor']}
          else
            nil
          end
        end
      end
    end
  end
end
