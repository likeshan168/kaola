class ActiveRecord::Base
  
  #给列表页list对象里的每个对象加载对应的table表示的many关系
  def self.many_caches(table, list, size=100)
    ret = []
    names = list.map{|x| x.many_cache_key(table, size)}
    caches = Rails.cache.read_multi(*names)
    list.each_with_index do |obj,i|
      cache = caches[names[i]]
      unless cache
        key = obj.many_cache_key(table, size)
        cache = obj.many_load(table, size)
        Rails.cache.write(key, cache)
      end
      ret[i] = cache
    end
    ret
  end
  
  #给当前对象加载table表示的many关系
  def many_cache(table, size=100, depth=1)
    key = many_cache_key(table, size, depth)
    Rails.cache.fetch(key) do
      self.many_load(table, size, depth)
    end
  end
  
  def many_load(table, size=100, depth=1)
    arr = self.send(table).limit(size).to_a
    arr = arr.map{|x| x.filter_attributes}
    if depth>1
      raise "非自引用表不支持depth参数" unless self.class.table_name==table
      arr.each do |hash|
        obj = self.class.new(hash)
        hash[table] = obj.many_load(table, size, depth-1)
      end
    end
    arr
  end
  
  def many_cache_key(table, size=100, depth=1)
    class_name = table.singularize.camelize
    clazz = Object.const_get(class_name)
    timestamp = clazz.request_cache_of_class_timestamp
    "#{clazz.prefix}#{table}_#{timestamp}:#{self.class.name}_#{self.id}-#{size}-#{depth}"
  end
  
  #记录当前的表的timestamp， 用于集合对象的缓存过期。只要表里任意一个CUD，对过期本表的所有list类缓存
  def self.get_class_timestamp
    Rails.cache.fetch(timestamp_key) do
      1
    end
  end
  
  def self.timestamp_key
    "timestamp:#{name}"
  end
  
  def self.request_cache_of_class_timestamp
    key = timestamp_key
    return RequestStore.store[key] if RequestStore.store.has_key? key
    ret = get_class_timestamp 
    RequestStore.store[key] = ret
    ret
  end

   
end
