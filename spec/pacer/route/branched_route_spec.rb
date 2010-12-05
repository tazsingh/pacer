require 'spec_helper'

describe BranchedRoute do
  before :all do
    @g = Pacer.tg 'spec/data/pacer.graphml'
    @br = @g.v(:type => 'person').
      branch { |b| b.out_e.in_v(:type => 'project') }.
      branch { |b| b.out_e.in_v.out_e }
  end

  describe '#inspect' do
    it 'should include both branches when inspecting' do
      @br.inspect.should ==
        '#<IndexedVertices -> Branched { #<V -> Edges(OUT_EDGES) -> Vertices(IN_VERTEX, [{:type=>"project"}])> | #<V -> Edges(OUT_EDGES) -> Vertices(IN_VERTEX) -> Edges(OUT_EDGES)> }>'
    end
  end

  it 'should return matches in round robin order by default' do
    @br.to_a.should ==
      [@g.vertex(1), @g.edge(3),
       @g.vertex(4), @g.edge(2),
       @g.vertex(2), @g.edge(4),
       @g.vertex(3), @g.edge(6), @g.edge(5), @g.edge(7)]
  end

  it '#exhaustive should return matches in exhaustive merge order' do
    @br.exhaustive.to_a.should ==
      [@g.vertex(1), @g.vertex(4), @g.vertex(2), @g.vertex(3),
        @g.edge(3), @g.edge(2), @g.edge(4), @g.edge(6), @g.edge(5), @g.edge(7)]
  end

  it { @br.branch_count.should == 2 }
  it { @br.should_not be_root }

  describe '#mixed' do
    it { @br.mixed.to_a.should == @br.to_a }
  end

  describe 'branch chaining bug' do
    before do
      @linear = Pacer.tg
      @a, @b, @c, @d = @linear.add_vertex('a'), @linear.add_vertex('b'), @linear.add_vertex('c'), @linear.add_vertex('d')
      @ab = @linear.add_edge nil, @a, @b, 'to'
      @bc = @linear.add_edge nil, @b, @c, 'to'
      @cd = @linear.add_edge nil, @c, @d, 'to'
      @source = VerticesRoute.from_vertex_ids @linear, ['a', 'b']

      single = @source.branch { |v| v.out_e.in_v }.branch { |v| v.out_e.in_v }
      @single_v = single.v
      @single_m = single.mixed

      @v = single.v.branch { |v| v.out_e.in_v }.branch { |v| v.out_e.in_v }
      @m = single.mixed.branch { |v| v.out_e.in_v }.branch { |v| v.out_e.in_v }
      @ve = single.exhaustive.v.branch { |v| v.out_e.in_v }.branch { |v| v.out_e.in_v }.exhaustive
      @me = single.exhaustive.mixed.branch { |v| v.out_e.in_v }.branch { |v| v.out_e.in_v }.exhaustive
    end

    it { @single_v.count.should == 4 }
    it { @single_m.count.should == 4 }
    it { @single_v.group_count { |v| v.id }.should ==  { 'b' => 2, 'c' => 2 } }
    it { @single_m.group_count { |v| v.id }.should ==  { 'b' => 2, 'c' => 2 } }

    it { @v.count.should ==  8 }
    it { @m.count.should ==  8 }
    it { @ve.count.should == 8 }
    it { @me.count.should == 8 }

    it { @v.group_count { |v| v.id }.should ==  { 'c' => 4, 'd' => 4 } }
    it { @m.group_count { |v| v.id }.should ==  { 'c' => 4, 'd' => 4 } }
    it { @ve.group_count { |v| v.id }.should == { 'c' => 4, 'd' => 4 } }
    it { @me.group_count { |v| v.id }.should == { 'c' => 4, 'd' => 4 } }

    it do
      @single_v.paths.map(&:to_a).should ==
        [[@a, @ab, @b],
         [@b, @bc, @c],
         [@a, @ab, @b],
         [@b, @bc, @c]]
    end

    it do
      @v.to_a.should == [@c, @c, @d, @d, @c, @c, @d, @d]
      @v.paths.map(&:to_a).should ==
        [[@a, @ab, @b, @bc, @c], [@a, @ab, @b, @bc, @c], [@b, @bc, @c, @cd, @d], [@b, @bc, @c, @cd, @d],
         [@a, @ab, @b, @bc, @c], [@a, @ab, @b, @bc, @c], [@b, @bc, @c, @cd, @d], [@b, @bc, @c, @cd, @d]]
    end
    it do
      @v.to_a.should == [@c, @c, @d, @d, @c, @c, @d, @d]
      @v.paths.map(&:to_a).should ==
        [[@a, @ab, @b, @bc, @c], [@a, @ab, @b, @bc, @c], [@b, @bc, @c, @cd, @d], [@b, @bc, @c, @cd, @d],
         [@a, @ab, @b, @bc, @c], [@a, @ab, @b, @bc, @c], [@b, @bc, @c, @cd, @d], [@b, @bc, @c, @cd, @d]]
    end
    it do
      @v.to_a.should == [@c, @c, @d, @d, @c, @c, @d, @d]
      @ve.paths.map(&:to_a).should ==
        [[@a, @ab, @b, @bc, @c], [@b, @bc, @c, @cd, @d],
         [@a, @ab, @b, @bc, @c], [@b, @bc, @c, @cd, @d],
         [@a, @ab, @b, @bc, @c], [@b, @bc, @c, @cd, @d],
         [@a, @ab, @b, @bc, @c], [@b, @bc, @c, @cd, @d]]
    end
    it do
      @me.to_a.should == [@c, @d, @c, @d, @c, @d, @c, @d]
      @me.paths.map(&:to_a).should ==
        [[@a, @ab, @b, @bc, @c], [@b, @bc, @c, @cd, @d],
         [@a, @ab, @b, @bc, @c], [@b, @bc, @c, @cd, @d],
         [@a, @ab, @b, @bc, @c], [@b, @bc, @c, @cd, @d],
         [@a, @ab, @b, @bc, @c], [@b, @bc, @c, @cd, @d]]
    end

  end

  describe 'chained branch routes' do
    describe 'once' do
      before do
        @once = @g.v.branch { |v| v.v }.branch { |v| v.v }.v
      end

      it 'should double each vertex' do
        @once.count.should == @g.v.count * 2
      end

      it 'should have 2 of each vertex' do
        @once.group_count { |v| v.id.to_i }.should == { 0 => 2, 1 => 2, 2 => 2, 3 => 2, 4 => 2, 5 => 2, 6 => 2 }
      end
    end

    describe 'twice' do
      before do
        # the difference must be with the object that's passed to the branch method
        single = @g.v.branch { |v| v.v }.branch { |v| v.v }
        @twice_v = single.v.branch { |v| v.v }.branch { |v| v.v }
        @twice_m = single.mixed.branch { |v| v.v }.branch { |v| v.v }
        @twice_v_e = single.exhaustive.v.branch { |v| v.v }.branch { |v| v.v }.exhaustive
        @twice_m_e = single.exhaustive.mixed.branch { |v| v.v }.branch { |v| v.v }.exhaustive
      end

      it { @twice_v.count.should == @g.v.count * 2 * 2 }
      it { @twice_m.count.should == @g.v.count * 2 * 2 }
      it { @twice_v_e.count.should == @g.v.count * 2 * 2 }
      it { @twice_m_e.count.should == @g.v.count * 2 * 2 }

      describe 'should have 4 of each' do
        it { @twice_v.group_count { |v| v.id.to_i }.sort.should == { 0 => 4, 1 => 4, 2 => 4, 3 => 4, 4 => 4, 5 => 4, 6 => 4 }.sort }
        it { @twice_m.group_count { |v| v.id.to_i }.sort.should == { 0 => 4, 1 => 4, 2 => 4, 3 => 4, 4 => 4, 5 => 4, 6 => 4 }.sort }
        it { @twice_v_e.group_count { |v| v.id.to_i }.sort.should == { 0 => 4, 1 => 4, 2 => 4, 3 => 4, 4 => 4, 5 => 4, 6 => 4 }.sort }
        it { @twice_m_e.group_count { |v| v.id.to_i }.sort.should == { 0 => 4, 1 => 4, 2 => 4, 3 => 4, 4 => 4, 5 => 4, 6 => 4 }.sort }
      end
    end
  end

  describe 'route with a custom split pipe' do
    before do
      @r = @g.v.branch { |person| person.v }.branch { |project| project.v }.branch { |other| other.out_e }.split_pipe(Tackle::TypeSplitPipe).mixed
    end

    describe 'vertices' do
      it { @r.v.to_a.should == @r.v.uniq.to_a }
      it 'should have only all person and project vertices' do
        people_and_projects = Set[*@g.v(:type => 'person')] + Set[*@g.v(:type => 'project')]
        Set[*@r.v].should == people_and_projects
      end
    end

    describe 'edges' do
      it { @r.e.to_a.should == @r.e.uniq.to_a }
      it 'should have out edges from all vertices except person and project' do
        # TODO: this type of thing should be much easier
        people_and_projects = Set[*@g.v(:type => 'person')] + Set[*@g.v(:type => 'project')]
        vertices = @g.v.to_a - people_and_projects.to_a
        edges = Set[*vertices.map { |v| v.out_e.to_a }.flatten]
        Set[*@r.e].should == edges
      end
    end

    describe 'chained' do
      def add_branch(vertices_path)
        vertices_path.
          branch { |person| person.out_e.in_v }.
          branch { |project| project.v }.
          branch { |other| other.out_e.in_v }.split_pipe(Tackle::TypeSplitPipe).v
      end

      it 'should have 5 unique elements when run once' do
        @g.v.repeat(1) { |repeater| add_branch(repeater) }.count.should == 12
        @g.v.repeat(1) { |repeater| add_branch(repeater) }.uniq.count.should == 5
      end

      it 'should have 4 unique elements when run twice' do
        @g.v.repeat(2) { |repeater| add_branch(repeater) }.count.should == 14
        @g.v.repeat(2) { |repeater| add_branch(repeater) }.uniq.count.should == 4
      end

      it 'should have 4 unique elements when run thrice' do
        @g.v.repeat(3) { |repeater| add_branch(repeater) }.count.should == 14
        @g.v.repeat(3) { |repeater| add_branch(repeater) }.uniq.count.should == 4
      end
    end
  end
end