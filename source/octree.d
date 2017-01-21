import intersection;
import renderer;
import std.math: abs;
import std.stdio;
import vec3;

// Generation code adapted from http://cg.alexandra.dk/?p=3836

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
    public Aabb buildAabb;
    public Aabb worldAabb;
    public NodeType nodeType;
    public float distanceToSurface;
}

public Vec3 uniformSphericalSampling()
{
    return Vec3( 1, 1, 1 );
}

public class Octree
{
    this( Vertex[] vertices, Face[] indices, int voxelSize, int borderSize )
    {
        this.voxelSize = voxelSize;
        
        Vertex[] flattenedVertices = new Vertex[ indices.length * 3 ];
        flattenVertices( vertices, indices, flattenedVertices );

        Aabb meshAabb = getMeshAABB( flattenedVertices );

        for (int dirIndex = 0; dirIndex < 200; ++dirIndex)
        {
            sampleDirections ~= uniformSphericalSampling();
        }

        // 1. Scales the AABB to find the correct octree dimension.
        meshAabb.min.x *= (1.0f / voxelSize);
        meshAabb.min.y *= (1.0f / voxelSize);
        meshAabb.min.z *= (1.0f / voxelSize);
        meshAabb.max.x *= (1.0f / voxelSize);
        meshAabb.max.y *= (1.0f / voxelSize);
        meshAabb.max.z *= (1.0f / voxelSize);

        //writeln("min AABB: ", meshAABBMin.x, ", ", meshAABBMin.y, ", ", meshAABBMin.z );
        //writeln("max AABB: ", meshAABBMax.x, ", ", meshAABBMax.y, ", ", meshAABBMax.z );

        // 2. Finds the longest axis.
        Vec3 dim = meshAabb.max - meshAabb.min;
        octreeDim = nextPowerOfTwo( cast(int)( dim.maxComponent() + borderSize ) );
        writeln("octreeDim: ", octreeDim);

        int worldSize = octreeDim * voxelSize;
        octreeOrigin = (dim / 2) - Vec3( worldSize / 2, worldSize / 2, worldSize / 2 );
        writeln("octreeOrigin: ", octreeOrigin.x, ", ", octreeOrigin.y, ", ", octreeOrigin.z );

        // 3. Creates the octree root.
        Vec3 rootAABBMin = octreeOrigin;
        Vec3 rootAABBMax = octreeOrigin + Vec3( worldSize, worldSize, worldSize );

        // 4. Subdivision
        rootNode = new OctreeNode();
        subdivide( rootNode, vertices, indices );
        const float minCoverage = 0.9f;
        updateInternalEmptyLeafsSign( rootNode, rootNode, minCoverage );
    }

    public Vec3[] getLines()
    {
        Vec3[] lines;
        getNodeLines( rootNode, lines );
        return lines;
    }

    private Vec3[] getNodeLines( OctreeNode node, Vec3[] lines )
    {
        if (node.nodeType != NodeType.EmptyLeaf)
        {
            lines ~= node.worldAabb.getLines();

            for (int childIndex = 0; childIndex < 8; ++childIndex)
            {
                getNodeLines( node.children[ childIndex ], lines );
            }
        }

        return lines;
    }

    private void updateInternalEmptyLeafsSign( OctreeNode rootNode, OctreeNode node, float minCoverage )
    {
        if (node is null)
        {
            return;
        }

        if (node.nodeType == NodeType.Leaf)
        {
            return;
        }

        if (node.nodeType == NodeType.Internal)
        {
            for (int childIndex = 0; childIndex < 8; ++childIndex)
            {
                updateInternalEmptyLeafsSign( rootNode, node.children[ childIndex ], minCoverage );
            }

            return;
        }

        int coverage = 0;
        int misses = 0;
        const int sampleDirectionsLength = 200;
        int maxMisses = sampleDirectionsLength / 4;

        for (int i = 0; i < sampleDirectionsLength; ++i)
        {
        
        }
    }

    private void subdivide( OctreeNode parentNode, Vertex[] vertices, Face[] nodeTriangleIndices )
    {
        uint childIndex = 0;
        int aabbDim = cast(int)( (parentNode.buildAabb.max.x - parentNode.buildAabb.min.x) / 2 );

        for (int z = 0; z < 2; ++z)
        {
            for (int y = 0; y < 2; ++y)
            {
                for (int x = 0; x < 2; ++x)
                {
                    OctreeNode childNode = new OctreeNode();
                    childNode.buildAabb.min = parentNode.buildAabb.min + Vec3( aabbDim * x, aabbDim * y, aabbDim * z );
                    childNode.buildAabb.max = childNode.buildAabb.min + Vec3( aabbDim, aabbDim, aabbDim );
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
            
            childNode.worldAabb.min = octreeOrigin + childNode.buildAabb.min * voxelSize;
            childNode.worldAabb.max = octreeOrigin + childNode.buildAabb.max * voxelSize;

            for (int faceIndex = 0; faceIndex < nodeTriangleIndices.length; ++faceIndex)
            {
                Vec3[ 3 ] triangleVertices;
                
                float[ 3 ] pos = vertices[ nodeTriangleIndices[ faceIndex ].a ].pos;
                triangleVertices[ 0 ] = Vec3( pos[ 0 ], pos[ 1 ], pos[ 2 ] );

                pos = vertices[ nodeTriangleIndices[ faceIndex ].b ].pos;
                triangleVertices[ 1 ] = Vec3( pos[ 0 ], pos[ 1 ], pos[ 2 ] );

                pos = vertices[ nodeTriangleIndices[ faceIndex ].c ].pos;
                triangleVertices[ 2 ] = Vec3( pos[ 0 ], pos[ 1 ], pos[ 2 ] );

                if (triangleIntersectsAABB( triangleVertices, childNode.worldAabb ))
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
                else
                {
                    childNode.nodeType = NodeType.Internal;

                    Face[] childTriangles = new Face[ childTriangleIndices.length / 3 ];
                    int i = 0;
                    for (int triIndex = 0; triIndex < childTriangleIndices.length; triIndex += 3)
                    {
                        childTriangles[ i ].a = cast(ushort)childTriangleIndices[ triIndex * 3 + 0 ];
                        childTriangles[ i ].b = cast(ushort)childTriangleIndices[ triIndex * 3 + 1 ];
                        childTriangles[ i ].c = cast(ushort)childTriangleIndices[ triIndex * 3 + 2 ];
                        ++i;
                    }

                    subdivide( childNode, vertices, childTriangles );
                }
            }
        }
    }

    private void updateLeafNodeDistanceValue( OctreeNode leafNode, Vertex[] vertices, int[] faces )
    {
        float minDistance = float.max;

        for (int faceIndex = 0; faceIndex < faces.length; ++faceIndex)
        {
            Vec3[ 3 ] triangleVerts;
            triangleVerts[ 0 ] = Vec3( vertices[ faceIndex + 0 ].pos[ 0 ], vertices[ faceIndex + 0 ].pos[ 1 ], vertices[ faceIndex + 0 ].pos[ 2 ] );
            triangleVerts[ 1 ] = Vec3( vertices[ faceIndex + 1 ].pos[ 0 ], vertices[ faceIndex + 1 ].pos[ 1 ], vertices[ faceIndex + 1 ].pos[ 2 ] );
            triangleVerts[ 2 ] = Vec3( vertices[ faceIndex + 2 ].pos[ 0 ], vertices[ faceIndex + 2 ].pos[ 1 ], vertices[ faceIndex + 2 ].pos[ 2 ] );

            const Vec3 normal = cross( triangleVerts[ 2 ] - triangleVerts[ 0 ], triangleVerts[ 1 ] - triangleVerts[ 0 ] );
            const Vec3 closestPoint = closestPointOnTriangle( triangleVerts, leafNode.worldAabb, leafNode.worldAabb.getCenter() );
            Vec3 delta = closestPoint - leafNode.worldAabb.getCenter();
            const float sign = (dot( delta, normal ) < 0) ? -1 : 1;
            float distance = length( delta );

            if (distance < abs( minDistance ))
            {
                minDistance = distance * sign;
            }
        }

        leafNode.distanceToSurface = minDistance;
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

    private Aabb getMeshAABB( Vertex[] vertices )
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

        return Aabb( meshAABBMin, meshAABBMax );
    }

    private float voxelSize;
    private int octreeDim;
    private Vec3 octreeOrigin;
    private Vec3[] sampleDirections;
    private OctreeNode rootNode;
}

unittest
{
    assert( nextPowerOfTwo( 1 ) == 2, "nextPowerOfTwo failed" );
    assert( nextPowerOfTwo( 3 ) == 4, "nextPowerOfTwo failed" );
    assert( nextPowerOfTwo( 4 ) == 8, "nextPowerOfTwo failed" );
}
