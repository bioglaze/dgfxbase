import renderer;
import std.stdio;
import vec3;

int nextPowerOfTwo( int x )
{
    if (x < 0)
    {
        return 0;
    }

    --x;
    x |= x >> 1;
    x |= x >> 2;
    x |= x >> 4;
    x |= x >> 8;
    x |= x >> 16;
    
    return x + 1;
}

private enum NodeType
{
    Internal,
    EmptyLeaf,
    Leaf
}

private class OctreeNode
{
    public OctreeNode[ 8 ] children;
    public Vec3 buildAABBMin;
    public Vec3 buildAABBMax;
    public Vec3 worldAABBMin;
    public Vec3 worldAABBMax;
    public NodeType nodeType;
}

// Generation code adapted from http://cg.alexandra.dk/?p=3836
public class Octree
{
    this( Vertex[] vertices, Face[] indices, int voxelSize, int borderSize )
    {
        this.voxelSize = voxelSize;
        
        Vertex[] flattenedVertices = new Vertex[ indices.length * 3 ];
        flattenVertices( vertices, indices, flattenedVertices );

        Vec3 meshAABBMin, meshAABBMax;
        getMeshAABB( flattenedVertices, meshAABBMin, meshAABBMax );

        // 1. Scales the AABB to find the correct octree dimension.
        meshAABBMin.x *= (1.0f / voxelSize);
        meshAABBMin.y *= (1.0f / voxelSize);
        meshAABBMin.z *= (1.0f / voxelSize);
        meshAABBMax.x *= (1.0f / voxelSize);
        meshAABBMax.y *= (1.0f / voxelSize);
        meshAABBMax.z *= (1.0f / voxelSize);

        writeln("min AABB: ", meshAABBMin.x, ", ", meshAABBMin.y, ", ", meshAABBMin.z );
        writeln("max AABB: ", meshAABBMax.x, ", ", meshAABBMax.y, ", ", meshAABBMax.z );

        // 2. Finds the longest axis.
        Vec3 dim = meshAABBMax - meshAABBMin;
        octreeDim = nextPowerOfTwo( cast(int)( dim.maxComponent() + borderSize ) );
        writeln("octreeDim: ", octreeDim);

        int worldSize = octreeDim * voxelSize;
        octreeOrigin = (dim / 2) - Vec3( worldSize / 2, worldSize / 2, worldSize / 2 );
        writeln("octreeOrigin: ", octreeOrigin.x, ", ", octreeOrigin.y, ", ", octreeOrigin.z );

        // 3. Creates the octree root.
        Vec3 rootAABBMin = octreeOrigin;
        Vec3 rootAABBMax = octreeOrigin + Vec3( worldSize, worldSize, worldSize );

        // 4. Subdivision
        OctreeNode rootNode = new OctreeNode();
        subdivide( rootNode, vertices, indices );
    }

    private void subdivide( OctreeNode parentNode, Vertex[] vertices, Face[] nodeTriangleIndices )
    {
        uint childIndex = 0;
        int aabbDim = cast(int)( (parentNode.buildAABBMax.x - parentNode.buildAABBMin.x) / 2 );

        for (int z = 0; z < 2; ++z)
        {
            for (int y = 0; y < 2; ++y)
            {
                for (int x = 0; x < 2; ++x)
                {
                    OctreeNode childNode = new OctreeNode();
                    childNode.buildAABBMin = parentNode.buildAABBMin + Vec3( aabbDim * x, aabbDim * y, aabbDim * z );
                    childNode.buildAABBMax = childNode.buildAABBMin + Vec3( aabbDim, aabbDim, aabbDim );
                    parentNode.children[ childIndex ] = childNode;
                    ++childIndex;
                }
            }
        }

        // Subdivides the node.
        for (childIndex = 0; childIndex < 8; ++childIndex)
        {
            OctreeNode childNode = parentNode.children[ childIndex ];
            int[] childTriangleIndices;
            
            childNode.worldAABBMin = octreeOrigin + childNode.buildAABBMin * voxelSize;
            childNode.worldAABBMax = octreeOrigin + childNode.buildAABBMax * voxelSize;

            for (int faceIndex = 0; faceIndex < nodeTriangleIndices.length; ++faceIndex)
            {
                Vec3[ 3 ] triangleVertices;
                
                float[ 3 ] pos = vertices[ nodeTriangleIndices[ faceIndex ].a ].pos;
                triangleVertices[ 0 ] = Vec3( pos[ 0 ], pos[ 1 ], pos[ 2 ] );

                pos = vertices[ nodeTriangleIndices[ faceIndex ].b ].pos;
                triangleVertices[ 1 ] = Vec3( pos[ 0 ], pos[ 1 ], pos[ 2 ] );

                pos = vertices[ nodeTriangleIndices[ faceIndex ].c ].pos;
                triangleVertices[ 2 ] = Vec3( pos[ 0 ], pos[ 1 ], pos[ 2 ] );

                if (triangleIntersectsAABB( triangleVertices, childNode.worldAABBMin, childNode.worldAABBMax ))
                {
                    childTriangleIndices ~= faceIndex;
                }
            }

            if (childTriangleIndices.length == 0)
            {
                childNode.nodeType = NodeType.EmptyLeaf;
            }
            else
            {
                if (aabbDim == 1)
                {
                    childNode.nodeType = NodeType.Leaf;
                    updateLeafNodeDistanceValue( childNode, vertices, childTriangleIndices );
                }
            }
        }
    }

    private void updateLeafNodeDistanceValue( OctreeNode node, Vertex[] vertices, int[] faces )
    {
    
    }

    private bool triangleIntersectsAABB( Vec3[ 3 ] triangleVertices, Vec3 aabbMin, Vec3 aabbMax )
    {
        Vec3 boxCenter;
        boxCenter.x = (aabbMax.x - aabbMin.x) / 2;
        boxCenter.y = (aabbMax.y - aabbMin.y) / 2;
        boxCenter.z = (aabbMax.z - aabbMin.z) / 2;

        Vec3 boxHalfSize;
        boxHalfSize.x = (aabbMax.x - aabbMin.x) / 2;

        return true;
    }

    private void flattenVertices( Vertex[] vertices, Face[] indices, out Vertex[] flattenedVertices )
    {
        foreach (face; indices)
        {
            flattenedVertices ~= vertices[ face.a ];
            flattenedVertices ~= vertices[ face.b ];
            flattenedVertices ~= vertices[ face.c ];
        }
    }

    private void getMeshAABB( Vertex[] vertices, out Vec3 aabbMin, out Vec3 aabbMax )
    {
        Vec3 meshAABBMin = Vec3( int.max, int.max, int.max );
        Vec3 meshAABBMax = Vec3( int.min, int.min, int.min );

        foreach(vertex; vertices)
        {
            if (vertex.pos[ 0 ] < meshAABBMin.x)
            {
                meshAABBMin.x = vertex.pos[ 0 ];
            }
            if (vertex.pos[ 1 ] < meshAABBMin.y)
            {
                meshAABBMin.y = vertex.pos[ 1 ];
            }
            if (vertex.pos[ 2 ] < meshAABBMin.z)
            {
                meshAABBMin.z = vertex.pos[ 2 ];
            }

            if (vertex.pos[ 0 ] > meshAABBMax.x)
            {
                meshAABBMax.x = vertex.pos[ 0 ];
            }
            if (vertex.pos[ 1 ] > meshAABBMax.y)
            {
                meshAABBMax.y = vertex.pos[ 1 ];
            }
            if (vertex.pos[ 2 ] > meshAABBMax.z)
            {
                meshAABBMax.z = vertex.pos[ 2 ];
            }
        }

        aabbMin = meshAABBMin;
        aabbMax = meshAABBMax;
    }

    private float voxelSize;
    private int octreeDim;
    private Vec3 octreeOrigin;
}

unittest
{
    assert( nextPowerOfTwo( 1 ) == 2, "nextPowerOfTwo failed" );
    assert( nextPowerOfTwo( 3 ) == 4, "nextPowerOfTwo failed" );
    assert( nextPowerOfTwo( 4 ) == 8, "nextPowerOfTwo failed" );
}
