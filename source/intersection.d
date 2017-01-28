import std.math: abs, fmax, fmin;
import vec3;

// Adapted from http://fileadmin.cs.lth.se/cs/Personal/Tomas_Akenine-Moller/code/

public struct Aabb
{
    this( Vec3 min, Vec3 max )
    {
        this.min = min;
        this.max = max;
    }

    public Vec3 getCenter() const
    {
        return (min + max) / 2;
    }

    public Vec3 getHalfSize() const
    {
        return (max - min) / 2;
    }

    public Vec3[] getLines() const
    {
        Vec3[] outLines = new Vec3[ 24 ];

        outLines[ 0 ] = Vec3( min.x, min.y, min.z );
        outLines[ 1 ] = Vec3( max.x, min.y, min.z );

        outLines[ 2 ] = Vec3( min.x, min.y, min.z );
        outLines[ 3 ] = Vec3( min.x, max.y, min.z );

        outLines[ 4 ] = Vec3( min.x, min.y, min.z );
        outLines[ 5 ] = Vec3( min.x, min.y, max.z );

        outLines[ 6 ] = Vec3( max.x, min.y, max.z );
        outLines[ 7 ] = Vec3( min.x, min.y, max.z );

        outLines[ 8 ] = Vec3( max.x, min.y, max.z );
        outLines[ 9 ] = Vec3( max.x, max.y, max.z );

        outLines[10 ] = Vec3( max.x, min.y, max.z );
        outLines[11 ] = Vec3( max.x, min.y, min.z );

        outLines[12 ] = Vec3( max.x, max.y, min.z );
        outLines[13 ] = Vec3( max.x, min.y, min.z );

        outLines[14 ] = Vec3( max.x, max.y, min.z );
        outLines[15 ] = Vec3( min.x, max.y, min.z );

        outLines[16 ] = Vec3( max.x, max.y, min.z );
        outLines[17 ] = Vec3( max.x, max.y, max.z );

        outLines[18 ] = Vec3( min.x, max.y, max.z );
        outLines[19 ] = Vec3( min.x, max.y, min.z );

        outLines[20 ] = Vec3( min.x, max.y, max.z );
        outLines[21 ] = Vec3( max.x, max.y, max.z );

        outLines[22 ] = Vec3( min.x, max.y, max.z );
        outLines[23 ] = Vec3( min.x, min.y, max.z );

        return outLines;
    }

    public Vec3 min;
    public Vec3 max;
}

public float saturate( float a )
{
    return fmax( 0, fmin( a, 1 ) );
}

public bool rayBoxIntersection( Vec3 rayOrigin, Vec3 rayDirection, Aabb aabb )
{
	float l1   = (aabb.min.x - rayOrigin.x) * (1.0f / rayDirection.x);
	float l2   = (aabb.max.x - rayOrigin.x) * (1.0f / rayDirection.x);

	float tmin = fmin( l1, l2 );
	float tmax = fmax( l1, l2 );

	l1   = (aabb.min.y - rayOrigin.y) * (1.0f / rayDirection.y);
	l2   = (aabb.max.y - rayOrigin.y) * (1.0f / rayDirection.y);

	tmin = fmax( fmin( l1, l2 ), tmin );
	tmax = fmin( fmax( l1, l2 ), tmax );

	l1   = (aabb.min.z - rayOrigin.z) * (1.0f / rayDirection.z);
	l2   = (aabb.max.z - rayOrigin.z) * (1.0f / rayDirection.z);

	tmin = fmax( fmin( l1, l2 ), tmin );
	tmax = fmin( fmax( l1, l2 ), tmax );
	tmin = fmax( 0.0f, tmin );

	return tmax > tmin;
}

public Vec3 closestPointOnTriangle( Vec3[ 3 ] triangleVerts, Aabb nodeWorldAabb, Vec3 pos )
{
    const Vec3 edge0 = triangleVerts[ 1 ] - triangleVerts[ 0 ];
    const Vec3 edge1 = triangleVerts[ 2 ] - triangleVerts[ 0 ];
    const Vec3 v0 = triangleVerts[ 0 ] - pos;

    const float a = dot( edge0, edge0 );
    const float b = dot( edge0, edge1 );
    const float c = dot( edge1, edge1 );
    const float d = dot( edge0, v0 );
    const float e = dot( edge1, v0 );

    float det = a * c - b * b;
    float   s = b * e - c * d;
    float   t = b * d - a * e;

    if (s + t < det)
    {
        if (s < 0)
        {
            if (t < 0)
            {
                if (d < 0)
                {
                    s = saturate( -d / a );
                    t = 0;
                }
                else
                {
                    s = 0;
                    t = saturate( -e / c );
                }
            }
            else
            {
                s = 0;
                t = saturate( -e / c );
            }
        }
        else if (t < 0)
        {
            s = saturate( -d / a );
            t = 0;
        }
        else
        {
            const float invDet = 1.0f /  det;
            s *= invDet;
            t *= invDet;
        }
    }
    else
    {
        if (s < 0)
        {
            const float tmp0 = b + d;
            const float tmp1 = c + e;

            if (tmp1 > tmp0)
            {
                const float numer = tmp1 - tmp0;
                const float denom = a - 2 * b + c;
                s = saturate( numer / denom );
                t = 1 - s;
            }
            else
            {
                t = saturate( -e / c );
                s = 0;
            }
        }
        else if (t < 0)
		{
			if (a + d > b + e)
			{
				const float numer = c + e - b - d;
				const float denom = a - 2 * b + c;
				s = saturate( numer / denom );
				t = 1 - s;
			}
			else
			{
				s = saturate( -e / c );
				t = 0;
			}
		}
		else
		{
			const float numer = c + e - b - d;
			const float denom = a - 2 * b + c;
			s = saturate( numer / denom );
			t = 1 - s;
		}
    }

    return triangleVerts[ 0 ] + edge0 * s + edge1 * t;
}

public bool triangleIntersectsAABB( Vec3[ 3 ] triangleVertices, Aabb aabb )
{
    Vec3 boxCenter = aabb.getCenter();
    Vec3 boxHalfSize = aabb.getHalfSize();

    return triBoxOverlap( boxCenter, boxHalfSize, triangleVertices ) > 0;
}

public bool planeBoxOverlap( Vec3 normal, Vec3 vert, Vec3 maxBox )
{
    Vec3 vMin;
    Vec3 vMax;

    if (normal.x > 0)
    {
        vMin.x = -maxBox.x - vert.x;
        vMax.x =  maxBox.x - vert.x;
    }
    else
    {
        vMin.x =  maxBox.x - vert.x;
        vMax.x = -maxBox.x - vert.x;
    }

    if (normal.y > 0)
    {
        vMin.y = -maxBox.y - vert.y;
        vMax.y =  maxBox.y - vert.y;
    }
    else
    {
        vMin.y =  maxBox.y - vert.y;
        vMax.y = -maxBox.y - vert.y;
    }

    if (normal.z > 0)
    {
        vMin.z = -maxBox.z - vert.z;
        vMax.z =  maxBox.z - vert.z;
    }
    else
    {
        vMin.z =  maxBox.z - vert.z;
        vMax.z = -maxBox.z - vert.z;
    }

    if (dot( normal, vMin ) > 0)
    {
        return false;
    }

    if (dot( normal, vMax ) >= 0)
    {
        return true;
    }

    return false;
}

public bool triBoxOverlap( Vec3 boxCenter, Vec3 boxHalfSize, Vec3[] triVerts )
{
    const Vec3 v0 = triVerts[ 0 ] - boxCenter;
    const Vec3 v1 = triVerts[ 1 ] - boxCenter;
    const Vec3 v2 = triVerts[ 2 ] - boxCenter;

    const Vec3 edge0 = v1 - v0;
    const Vec3 edge1 = v2 - v1;
    const Vec3 edge2 = v0 - v2;

    Vec3 absEdge = Vec3( abs( edge0.x ), abs( edge0.y ), abs( edge0.z ) );
    float p0, p1, p2;
    float min, max;
    float rad;

    // AXISTEST_X01
    {
        p0 = edge0.z * v0.y - edge0.y * v0.z;
        p2 = edge0.z * v2.y - edge0.y * v2.z;

        if (p0 < p2)
        {
            min = p0;
            max = p2;
        }
        else
        {
            min = p2;
            max = p0;
        }

        rad = absEdge.z * boxHalfSize.y + absEdge.y * boxHalfSize.z;

        if (min > rad || max < -rad)
        {
            return false;
        }
    }

    // AXISTEST_Y02
    {
        p0 = -edge0.z * v0.x - edge0.y * v0.z;
        p2 = -edge0.z * v2.x - edge0.y * v2.z;

        if (p0 < p2)
        {
            min = p0;
            max = p2;
        }
        else
        {
            min = p2;
            max = p0;
        }

        rad = absEdge.z * boxHalfSize.x + absEdge.x * boxHalfSize.z;

        if (min > rad || max < -rad)
        {
            return false;
        }
    }

    // AXISTEST_Z12
    {
        p0 = -edge0.y * v1.x - edge0.x * v1.y;
        p2 = -edge0.y * v2.x - edge0.x * v2.y;

        if (p2 < p1)
        {
            min = p2;
            max = p1;
        }
        else
        {
            min = p1;
            max = p2;
        }

        rad = absEdge.y * boxHalfSize.x + absEdge.x * boxHalfSize.y;

        if (min > rad || max < -rad)
        {
            return false;
        }
    }

    absEdge = Vec3( abs( edge1.x ), abs( edge1.y ), abs( edge1.z ) );

    // AXISTEST_X01
    {
        p0 = edge1.z * v0.y - edge1.y * v0.z;
        p2 = edge1.z * v2.y - edge1.y * v2.z;

        if (p0 < p2)
        {
            min = p0;
            max = p2;
        }
        else
        {
            min = p2;
            max = p0;
        }

        rad = absEdge.z * boxHalfSize.y + absEdge.y * boxHalfSize.z;

        if (min > rad || max < -rad)
        {
            return false;
        }
    }

    // AXISTEST_Y02
    {
        p0 = -edge1.z * v0.x - edge1.y * v0.z;
        p2 = -edge1.z * v2.x - edge1.y * v2.z;

        if (p0 < p2)
        {
            min = p0;
            max = p2;
        }
        else
        {
            min = p2;
            max = p0;
        }

        rad = absEdge.z * boxHalfSize.x + absEdge.x * boxHalfSize.z;

        if (min > rad || max < -rad)
        {
            return false;
        }
    }

    // AXISTEST_Z0
    {
        p0 = -edge1.y * v0.x - edge1.x * v0.y;
        p2 = -edge1.y * v1.x - edge1.x * v1.y;

        if (p0 < p1)
        {
            min = p0;
            max = p1;
        }
        else
        {
            min = p1;
            max = p0;
        }

        rad = absEdge.y * boxHalfSize.x + absEdge.x * boxHalfSize.y;

        if (min > rad || max < -rad)
        {
            return false;
        }
    }

    absEdge = Vec3( abs( edge2.x ), abs( edge2.y ), abs( edge2.z ) );

    // AXISTEST_X2 (e2[Z], e2[Y], fez, fey);
    {
        p0 = -edge2.z * v0.y - edge2.y * v0.y;
        p1 = -edge2.z * v1.y - edge2.y * v1.y;

        if (p0 < p1)
        {
            min = p0;
            max = p1;
        }
        else
        {
            min = p1;
            max = p0;
        }

        rad = absEdge.z * boxHalfSize.x + absEdge.y * boxHalfSize.z;

        if (min > rad || max < -rad)
        {
            return false;
        }
    }

    // AXISTEST_Y1(e2[Z], e2[X], fez, fex);
    {
        p0 = -edge2.z * v0.x - edge2.x * v0.z;
        p1 = -edge2.z * v1.x - edge2.x * v1.z;

        if (p0 < p1)
        {
            min = p0;
            max = p1;
        }
        else
        {
            min = p1;
            max = p0;
        }

        rad = absEdge.z * boxHalfSize.x + absEdge.x * boxHalfSize.z;

        if (min > rad || max < -rad)
        {
            return false;
        }
    }

    // AXISTEST_Z12(e2[Y], e2[X], fey, fex);
    {
        p0 = edge2.y * v1.x - edge2.x * v1.y;
        p1 = edge2.y * v2.x - edge2.x * v2.y;

        if (p2 < p1)
        {
            min = p2;
            max = p1;
        }
        else
        {
            min = p1;
            max = p2;
        }

        rad = absEdge.y * boxHalfSize.x + absEdge.x * boxHalfSize.y;

        if (min > rad || max < -rad)
        {
            return false;
        }
    }

    // FINDMINMAX(v0[X],v1[X],v2[X],min,max);
    {
        min = v0.x;
        max = v0.x;

        if (v1.x < min) min = v1.x;
        if (v1.x > max) max = v1.x;
        if (v2.x < min) min = v2.x;
        if (v2.x > max) max = v2.x;

        if (min > boxHalfSize.x || max < -boxHalfSize.x)
        {
            return false;
        }
    }

    // FINDMINMAX(v0[Y],v1[Y],v2[Y],min,max);
    {
        min = v0.y;
        max = v0.y;

        if (v1.y < min) min = v1.y;
        if (v1.y > max) max = v1.y;
        if (v2.y < min) min = v2.y;
        if (v2.y > max) max = v2.y;

        if (min > boxHalfSize.y || max < -boxHalfSize.y)
        {
            return false;
        }
    }

    // FINDMINMAX(v0[Z],v1[Z],v2[Z],min,max);
    {
        min = v0.z;
        max = v0.z;

        if (v1.z < min) min = v1.z;
        if (v1.z > max) max = v1.z;
        if (v2.z < min) min = v2.z;
        if (v2.z > max) max = v2.z;

        if (min > boxHalfSize.z || max < -boxHalfSize.z)
        {
            return false;
        }
    }

    Vec3 normal = cross( v1, v2 );

    return planeBoxOverlap( normal, v0, boxHalfSize );
}

unittest
{
    // triBoxOverlap

    // closestPointOnTriangle

    // triangleIntersectsAABB

    // planeBoxOverlap
    {
        immutable int[] expectedResults = [ 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 0, 0 ];

        float[ 3 ] normal;
        float[ 3 ] vert;
        float[ 3 ] maxbox;

        float[ 5 ] vertValues = [ -1, 0, 1, 2, 7 ];
        float[ 5 ] maxValues = [ -1, 0, 1, 2, 7 ];
        float[ 3 ] normalValues = [ -1, 0, 1 ];

        int i = 0;

        for (int m = 0; m < 5; ++m)
        {
            for (int v = 0; v < 5; ++v)
            {
                for (int n = 0; n < 3; ++n)
                {
                    normal[ 0 ] = normalValues[ n ];
                    normal[ 1 ] = normalValues[ (n + 1) % 3 ];
                    normal[ 2 ] = normalValues[ (n + 2) % 3 ];

                    vert[ 0 ] = vertValues[ v ];
                    vert[ 1 ] = vertValues[ 4 - v ];
                    vert[ 2 ] = vertValues[ v ];

                    maxbox[ 0 ] = maxValues[ 4 - m ];
                    maxbox[ 1 ] = maxValues[ m ];
                    maxbox[ 2 ] = maxValues[ 4 - m ];

                    int res = planeBoxOverlap( Vec3( normal[ 0 ], normal[ 1 ], normal[ 2 ] ), Vec3( vert[ 0 ], vert[ 1 ], vert[ 2 ] ), Vec3( maxbox[ 0 ], maxbox[ 1 ], maxbox[ 2 ] ) ) ? 1 : 0;
                    assert( res == expectedResults[ i ], "PlaneBoxOverlap test failed" );
                    ++i;
                }
            }
        }
    }
}
