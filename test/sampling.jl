@sampler Simple = begin
    @sample begin
        return SimpleScenario(-24.0 + randn(), -28.0 + randn(), 500.0 + randn(), 100 + randn(), probability = rand())
    end
end
